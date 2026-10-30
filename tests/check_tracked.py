"""Checks a .docx downloaded with "Word con revisioni", outside the browser.

uv run tests/check_tracked.py OUT.docx --browser JSON --left REF --right REF
JSON is what the e2e test read in the page: words added and removed by the text differences (ins, del),
how many differences add or remove words (insHunks, delHunks), the text of PDF sides (texts).
REF is the text the export must give back: a .docx (optionally path.docx:reject to read it with its own
revisions rejected), a .txt file, or "browser" for the text of that side as read by the page. "Accept all" must give the right text, "reject all" the left one,
compared as word sequences. If pandoc is available it is used as a second, independent reader.
Prints "ok" or the reasons it failed (exit 1)."""
import argparse, json, re, shutil, subprocess, sys, unicodedata, zipfile, pathlib
import xml.etree.ElementTree as ET

W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
TOK = re.compile(r'[^\W_]+|[^\s\w]|_')


def tokens(text, words_only=False):
    out = []
    for t in TOK.findall(unicodedata.normalize('NFKC', text)):
        t = re.sub('[’‘`´]', "'", t)
        t = re.sub('[“”«»„]', '"', t)
        t = re.sub('[–—]', '-', t)
        if not words_only or re.match(r'[^\W_]', t):
            out.append(t)
    return out


def parts(z):
    names = z.namelist()
    order = sorted(n for n in names if re.match(r'word/header\d*\.xml$', n)) + ['word/document.xml'] + sorted(n for n in names if re.match(r'word/footer\d*\.xml$', n))
    return [n for n in order if n in names]


def text_of(root, mode):
    """document text with every revision accepted or rejected"""
    gone = {W + 'del', W + 'moveFrom'} if mode == 'accept' else {W + 'ins', W + 'moveTo'}
    buf = []

    def walk(e, parent_tag):
        if e.tag in gone and not parent_tag.endswith('Pr'):
            return
        if e.tag in (W + 't', W + 'delText'):
            buf.append(e.text or '')
        elif e.tag in (W + 'tab', W + 'br', W + 'cr'):
            buf.append(' ')
        for c in e:
            walk(c, e.tag)
        if e.tag == W + 'p':
            buf.append('\n')
    walk(root, '')
    return ''.join(buf)


def docx_text(path, mode):
    with zipfile.ZipFile(path) as z:
        return ''.join(text_of(ET.fromstring(z.read(n)), mode) for n in parts(z))


BROWSER = {}


def ref_text(ref, side=None):
    if ref == 'browser':
        return BROWSER['texts'][side]
    if ref.endswith('.txt'):
        return pathlib.Path(ref).read_text(encoding='utf-8')
    path, _, mode = ref.partition('.docx:')
    path = path + '.docx' if mode else ref
    return docx_text(path, mode or 'accept')


def pandoc():
    for p in [shutil.which('pandoc'), str(pathlib.Path.home() / 'Applications/pandoc/pandoc')]:
        if p and pathlib.Path(p).exists():
            return p


def pandoc_words(exe, path, mode):
    out = subprocess.run([exe, '--track-changes=' + mode, '-f', 'docx', '-t', 'plain', '--wrap=none', path], capture_output=True, text=True, check=True).stdout
    return tokens(out, words_only=True)


def first_diff(a, b):
    for i, (x, y) in enumerate(zip(a, b)):
        if x != y:
            return {'at': i, 'got': ' '.join(a[max(0, i - 5):i + 6]), 'want': ' '.join(b[max(0, i - 5):i + 6])}
    return {'len': [len(a), len(b)], 'got_tail': ' '.join(a[min(len(a), len(b)):][:12]), 'want_tail': ' '.join(b[min(len(a), len(b)):][:12])}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--left', required=True)
    ap.add_argument('--right', required=True)
    ap.add_argument('--browser', required=True)
    a = ap.parse_args()
    raw = pathlib.Path(a.browser).read_text(encoding='utf-8').strip()
    try:
        BROWSER.update(json.loads(json.loads(raw)))
    except ValueError:
        print('FAIL page:', raw[:400])
        sys.exit(1)
    a.ins, a.dels = BROWSER['ins'], BROWSER['del']
    bad = {}
    try:
        z = zipfile.ZipFile(a.out)
    except zipfile.BadZipFile as e:
        print('FAIL not a zip:', e)
        sys.exit(1)
    if z.testzip() is not None:
        bad['crc'] = z.testzip()
    if z.namelist()[0] != '[Content_Types].xml':
        bad['first'] = z.namelist()[0]
    roots = {}
    for n in z.namelist():
        if n.endswith('.xml') or n.endswith('.rels'):
            try:
                root = ET.fromstring(z.read(n))
                if n in parts(z):
                    roots[n] = root
            except ET.ParseError as e:
                bad.setdefault('xml', []).append(f'{n}: {e}')
    if 'word/document.xml' not in roots:
        bad['document'] = 'missing or invalid'
    # revision marks: unique ids, ours carry the author
    ids, ins_words, del_words, n = [], 0, 0, {'ins': 0, 'del': 0}
    for root in roots.values():
        for tag in ('ins', 'del', 'moveFrom', 'moveTo'):
            for e in root.iter(W + tag):
                ids.append(e.get(W + 'id'))
                if e.get(W + 'author') != 'Raffronto':
                    bad.setdefault('author', set()).add(e.get(W + 'author'))
                text = ''.join(t.text or '' for t in e.iter() if t.tag in (W + 't', W + 'delText'))
                if text.strip():
                    n[tag] = n.get(tag, 0) + 1
                if tag == 'ins':
                    ins_words += len(tokens(text))
                elif tag == 'del':
                    del_words += len(tokens(text))
    if len(ids) != len(set(ids)):
        bad['ids'] = 'duplicate revision ids'
    if 'author' in bad:
        bad['author'] = sorted(map(str, bad['author']))
    if a.ins is not None and ins_words != a.ins:
        bad['ins_words'] = [ins_words, a.ins]
    if a.dels is not None and del_words != a.dels:
        bad['del_words'] = [del_words, a.dels]
    # every difference that adds words has at least one insertion, every one that removes words a deletion
    if n['ins'] < BROWSER['insHunks'] or n['del'] < BROWSER['delHunks']:
        bad['counts'] = {'ins': n['ins'], 'del': n['del'], 'hunks': [BROWSER['insHunks'], BROWSER['delHunks']]}
    left, right = ref_text(a.left, 0), ref_text(a.right, 1)
    if not bad.get('xml') and 'document' not in bad:
        acc, rej = tokens(docx_text(a.out, 'accept')), tokens(docx_text(a.out, 'reject'))
        if acc != tokens(right):
            bad['accept'] = first_diff(acc, tokens(right))
        if rej != tokens(left):
            bad['reject'] = first_diff(rej, tokens(left))
        exe = pandoc()
        if exe:
            # pandoc reads only the body: compare with the body of the reference (pandoc too) or the whole text
            def want(ref, side):
                if ref == 'browser' or ref.endswith('.txt'):
                    return tokens(ref_text(ref, side), words_only=True)
                path, _, mode = ref.partition('.docx:')
                return pandoc_words(exe, path + '.docx' if mode else ref, mode or 'accept')
            for mode, ref, side in (('accept', a.right, 1), ('reject', a.left, 0)):
                got = pandoc_words(exe, a.out, mode)
                w = want(ref, side)
                if got != w:
                    bad['pandoc_' + mode] = first_diff(got, w)
    if bad:
        print('FAIL', json.dumps(bad, ensure_ascii=False))
        sys.exit(1)
    print('ok', json.dumps({'file': BROWSER.get('name'), 'revisions': n, 'ins_words': ins_words, 'del_words': del_words, 'pandoc': bool(pandoc())}, ensure_ascii=False))


main()
