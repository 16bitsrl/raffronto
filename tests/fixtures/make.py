# /// script
# requires-python = ">=3.11"
# dependencies = ["reportlab>=4", "pyhanko==0.38.*", "cryptography>=43", "pillow>=11"]
# ///
"""Builds the e2e fixtures from scratch, with fictional content: uv run tests/fixtures/make.py

Everything is deterministic (fixed dates, fixed keys, fixed zip timestamps); only the digital
signatures differ between runs, because ECDSA signatures are randomised.
"""
import asyncio, datetime as dt, io, pathlib, re, struct, sys, zipfile, zlib
from xml.sax.saxutils import escape

sys.dont_write_bytecode = True
from texts import *  # noqa: E402,F403 (fictional texts)

HERE = pathlib.Path(__file__).parent
ZIP_TIME = (2026, 1, 1, 0, 0, 0)


# ---------- DOCX ----------

NS = ('xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"')
REL = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/'
XML = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'

STYLES = XML + f'''<w:styles {NS}>
<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="22"/><w:lang w:val="it-IT"/></w:rPr></w:rPrDefault>
<w:pPrDefault><w:pPr><w:spacing w:after="160" w:line="276" w:lineRule="auto"/><w:jc w:val="both"/></w:pPr></w:pPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:pPr><w:jc w:val="center"/><w:spacing w:after="120"/></w:pPr><w:rPr><w:b/><w:sz w:val="32"/><w:color w:val="1F3864"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Subtitle"><w:name w:val="Subtitle"/><w:basedOn w:val="Normal"/><w:pPr><w:jc w:val="center"/><w:spacing w:after="360"/></w:pPr><w:rPr><w:i/><w:color w:val="595959"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="240" w:after="80"/><w:jc w:val="left"/></w:pPr><w:rPr><w:b/><w:sz w:val="24"/><w:color w:val="1F3864"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Footer"><w:name w:val="footer"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:after="0"/><w:jc w:val="center"/></w:pPr><w:rPr><w:sz w:val="16"/><w:color w:val="595959"/></w:rPr></w:style>
</w:styles>'''


def zwrite(z, name, data):
    info = zipfile.ZipInfo(name, ZIP_TIME)
    info.compress_type = zipfile.ZIP_DEFLATED
    z.writestr(info, data)


def t(text):
    return f'<w:t xml:space="preserve">{escape(text)}</w:t>'


def para(text, style=None, jc=None, bold=False, extra=''):
    ppr = (f'<w:pStyle w:val="{style}"/>' if style else '') + (f'<w:jc w:val="{jc}"/>' if jc else '')
    rpr = '<w:rPr><w:b/></w:rPr>' if bold else ''
    return f'<w:p>{"<w:pPr>" + ppr + "</w:pPr>" if ppr else ""}<w:r>{rpr}{t(text)}</w:r>{extra}</w:p>'


def page_number_footer(label):
    fld = lambda f: f'<w:fldSimple w:instr=" {f} "><w:r><w:t>1</w:t></w:r></w:fldSimple>'
    return (XML + f'<w:ftr {NS}><w:p><w:pPr><w:pStyle w:val="Footer"/></w:pPr><w:r>{t(label + " - Pagina ")}</w:r>'
            f'{fld("PAGE")}<w:r>{t(" di ")}</w:r>{fld("NUMPAGES")}</w:p></w:ftr>')


def drawing(rid, cx_cm, cy_cm, name):
    cx, cy = round(cx_cm * 360000), round(cy_cm * 360000)
    return (f'<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="{cx}" cy="{cy}"/>'
            f'<wp:docPr id="1" name="{name}" descr="Logo {escape(LETTER_COMPANY)}"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
            f'<pic:pic><pic:nvPicPr><pic:cNvPr id="1" name="{name}"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
            f'<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>')


def write_docx(path, body, *, title, modified, created='2026-01-07T09:00:00Z', author='Ufficio segreteria',
               header=None, footer=None, header_rels=None, media=None):
    """body: document.xml body content; header/footer: full part xml; media: {zip path: bytes}"""
    doc_rels = [('rIdStyles', 'styles', 'styles.xml')]
    sect = ''
    if header:
        doc_rels.append(('rIdHeader', 'header', 'header1.xml'))
        sect += '<w:headerReference w:type="default" r:id="rIdHeader"/>'
    if footer:
        doc_rels.append(('rIdFooter', 'footer', 'footer1.xml'))
        sect += '<w:footerReference w:type="default" r:id="rIdFooter"/>'
    sect += ('<w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1418" w:right="1134" w:bottom="1418" w:left="1134" '
             'w:header="567" w:footer="567" w:gutter="0"/>')
    rels = lambda items: XML + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' + ''.join(
        f'<Relationship Id="{i}" Type="{REL}{ty}" Target="{tg}"/>' for i, ty, tg in items) + '</Relationships>'
    over = lambda part, ct: f'<Override PartName="/{part}" ContentType="application/vnd.openxmlformats-{ct}"/>'
    types = (XML + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
             '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
             '<Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/>'
             + over('word/document.xml', 'officedocument.wordprocessingml.document.main+xml')
             + over('word/styles.xml', 'officedocument.wordprocessingml.styles+xml')
             + (over('word/header1.xml', 'officedocument.wordprocessingml.header+xml') if header else '')
             + (over('word/footer1.xml', 'officedocument.wordprocessingml.footer+xml') if footer else '')
             + over('docProps/core.xml', 'package.core-properties+xml')
             + over('docProps/app.xml', 'officedocument.extended-properties+xml') + '</Types>')
    core = (XML + '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
            'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
            f'<dc:title>{escape(title)}</dc:title><dc:creator>{escape(author)}</dc:creator><cp:lastModifiedBy>{escape(author)}</cp:lastModifiedBy>'
            f'<dcterms:created xsi:type="dcterms:W3CDTF">{created}</dcterms:created>'
            f'<dcterms:modified xsi:type="dcterms:W3CDTF">{modified}</dcterms:modified></cp:coreProperties>')
    app = (XML + '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
           '<Application>Microsoft Office Word</Application></Properties>')
    with zipfile.ZipFile(path, 'w') as z:
        zwrite(z, '[Content_Types].xml', types)
        zwrite(z, '_rels/.rels', rels([('rId1', 'officeDocument', 'word/document.xml'),
                                       ('rId2', 'metadata/core-properties', 'docProps/core.xml'),
                                       ('rId3', 'extended-properties', 'docProps/app.xml')]).replace(
            REL + 'metadata/core-properties', 'http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties'))
        zwrite(z, 'docProps/core.xml', core)
        zwrite(z, 'docProps/app.xml', app)
        zwrite(z, 'word/_rels/document.xml.rels', rels(doc_rels))
        zwrite(z, 'word/styles.xml', STYLES)
        zwrite(z, 'word/document.xml', XML + f'<w:document {NS}><w:body>{body}<w:sectPr>{sect}</w:sectPr></w:body></w:document>')
        if header:
            zwrite(z, 'word/header1.xml', header)
            if header_rels:
                zwrite(z, 'word/_rels/header1.xml.rels', rels(header_rels))
        if footer:
            zwrite(z, 'word/footer1.xml', footer)
        for name, data in (media or {}).items():
            zwrite(z, name, data)


def png(w, h, rgb):
    raw = b''.join(b'\x00' + bytes(rgb) * w for _ in range(h))
    chunk = lambda ty, d: struct.pack('>I', len(d)) + ty + d + struct.pack('>I', zlib.crc32(ty + d) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')


def image_pair():
    """Same short text, one version with an inline picture and one without."""
    drawing_xml = '''<w:r><w:drawing><wp:inline><wp:extent cx="1270000" cy="635000"/><wp:docPr id="1" name="Logo"/>
<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="1" name="logo.png"/><pic:cNvPicPr/></pic:nvPicPr>
<pic:blipFill><a:blip r:embed="rIdImg"/></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1270000" cy="635000"/></a:xfrm><a:prstGeom prst="rect"/></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>'''
    for path, with_image in [('immagine-con.docx', True), ('immagine-senza.docx', False)]:
        p = lambda s: f'<w:p><w:r><w:t xml:space="preserve">{s}</w:t></w:r></w:p>'
        body = p('Dichiarazione di prova per il confronto delle immagini.') + (f'<w:p>{drawing_xml}</w:p>' if with_image else '') + p('Il testo resta uguale in entrambe le versioni del documento.')
        rels_doc = XML + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' + \
            (f'<Relationship Id="rIdImg" Type="{REL}image" Target="media/logo.png"/>' if with_image else '') + '</Relationships>'
        with zipfile.ZipFile(HERE / path, 'w') as z:
            zwrite(z, '[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>')
            zwrite(z, '_rels/.rels', f'<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="{REL}officeDocument" Target="word/document.xml"/></Relationships>')
            zwrite(z, 'word/_rels/document.xml.rels', rels_doc)
            zwrite(z, 'word/document.xml', f'<?xml version="1.0" encoding="UTF-8"?><w:document {NS}><w:body>{body}<w:sectPr/></w:body></w:document>')
            if with_image:
                zwrite(z, 'word/media/logo.png', png(80, 40, (220, 60, 120)))


def regulation():
    """Multi-page internal regulation, version 1 and version 2 (plain edits, no tracked changes)."""
    def body(articles, subtitle):
        out = para(REGULATION_TITLE, 'Title') + para(subtitle, 'Subtitle')
        for title, paras in articles:
            out += para(title, 'Heading1') + ''.join(para(p) for p in paras)
        return out

    v2 = [(title, list(paras)) for title, paras in REGULATION]
    sub2 = REGULATION_SUBTITLE
    for old, new in REGULATION_EDITS:
        hits = [(i, j) for i, (_, ps) in enumerate(v2) for j, p in enumerate(ps) if old in p] + ([('sub', 0)] if old in sub2 else [])
        assert len(hits) == 1, (old, hits)
        i, j = hits[0]
        if i == 'sub':
            sub2 = sub2.replace(old, new)
        else:
            v2[i][1][j] = v2[i][1][j].replace(old, new)
    sentence, target = REGULATION_MOVE
    src = [(i, j) for i, (_, ps) in enumerate(v2) for j, p in enumerate(ps) if p == sentence]
    assert len(src) == 1, sentence
    del v2[src[0][0]][1][src[0][1]]
    dst = next(ps for title, ps in v2 if title == target)
    dst[-1] += ' ' + sentence
    footer = page_number_footer('Regolamento interno')
    write_docx(HERE / 'regulation-v1.docx', body(REGULATION, REGULATION_SUBTITLE), title=REGULATION_TITLE,
               modified='2026-01-20T10:15:00Z', footer=footer)
    write_docx(HERE / 'regulation-v2.docx', body(v2, sub2), title=REGULATION_TITLE,
               modified='2026-02-11T16:40:00Z', footer=footer)


MARKUP = re.compile(r'\{\+(.*?)\+\}|\{-(.*?)-\}|\{<(.*?)<\}|\{>(.*?)>\}|([^{]+)')


def segments(text):
    for m in MARKUP.finditer(text):
        ins, dele, mfrom, mto, plain = m.groups()
        if ins is not None: yield 'ins', ins
        elif dele is not None: yield 'del', dele
        elif mfrom is not None: yield 'moveFrom', mfrom
        elif mto is not None: yield 'moveTo', mto
        else: yield None, plain


def statute():
    """Association statute: original, and the same statute with Word tracked changes (rejected = original)."""
    rev = dict(author='Giulia Ferri', date='2026-04-14T09:30:00Z')
    ids = iter(range(100, 1000))
    attrs = lambda: f'w:id="{next(ids)}" w:author="{rev["author"]}" w:date="{rev["date"]}"'
    moves = iter(range(1, 100))

    revised = para(STATUTE_TITLE, 'Title')
    original = [para(STATUTE_TITLE, 'Title')]
    carry = ''
    for style, text, mark in STATUTE:
        runs = ''
        rejected = ''
        for kind, s in segments(text):
            if kind is None:
                runs += f'<w:r>{t(s)}</w:r>'
            elif kind == 'ins':
                runs += f'<w:ins {attrs()}><w:r>{t(s)}</w:r></w:ins>'
            elif kind == 'del':
                runs += f'<w:del {attrs()}><w:r><w:delText xml:space="preserve">{escape(s)}</w:delText></w:r></w:del>'
            else:
                n = next(moves)
                tag = kind
                runs += (f'<w:{tag}RangeStart w:id="{n}" w:author="{rev["author"]}" w:date="{rev["date"]}" w:name="move{n}"/>'
                         f'<w:{tag} {attrs()}><w:r>{t(s)}</w:r></w:{tag}><w:{tag}RangeEnd w:id="{n}"/>')
            if kind in (None, 'del', 'moveFrom'):
                rejected += s
        mark_xml = f'<w:rPr><w:{mark} {attrs()}/></w:rPr>' if mark else ''
        ppr = f'<w:pPr><w:pStyle w:val="{style}"/>{mark_xml}</w:pPr>'
        revised += f'<w:p>{ppr}{runs}</w:p>'
        # original text: an inserted paragraph mark did not exist, so the paragraph joins the next one
        rejected = carry + rejected
        if mark == 'ins':
            carry = rejected
            continue
        carry = ''
        if rejected:
            original.append(para(rejected, None if style == 'Normal' else style))
    write_docx(HERE / 'statute.docx', ''.join(original), title=STATUTE_TITLE, modified='2026-03-02T11:00:00Z',
               created='2026-02-20T08:00:00Z', author='Anna Moretti')
    write_docx(HERE / 'statute-revisions.docx', revised, title=STATUTE_TITLE, modified='2026-04-14T18:20:00Z',
               created='2026-02-20T08:00:00Z', author='Giulia Ferri')


# ---------- logo ----------

def logo_png():
    from PIL import Image, ImageDraw, ImageFont
    w, h = 900, 270
    im = Image.new('RGB', (w, h), 'white')
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((10, 20, 240, 250), radius=36, fill=(31, 56, 100))
    for k, c in enumerate([(246, 178, 60), (230, 120, 50), (200, 70, 50)]):
        d.rectangle((50 + k * 55, 210 - (k + 2) * 38, 90 + k * 55, 210), fill=c)
    d.text((280, 50), 'OFFICINE', font=ImageFont.load_default(92), fill=(31, 56, 100))
    d.text((280, 150), 'BRENTA', font=ImageFont.load_default(92), fill=(200, 70, 50))
    buf = io.BytesIO()
    im.save(buf, 'PNG', optimize=True)
    return buf.getvalue()


LOGO_CM = (5.0, 1.5)


def letterhead_docx(logo):
    header = (XML + f'<w:hdr {NS}><w:p><w:pPr><w:spacing w:after="0"/><w:jc w:val="left"/></w:pPr>'
              f'{drawing("rIdLogo", *LOGO_CM, "logo.png")}</w:p></w:hdr>')
    footer = XML + f'<w:ftr {NS}>' + ''.join(para(line, 'Footer') for line in LETTER_FOOTER) + '</w:ftr>'
    body = ''
    for kind, text in LETTER:
        body += para(text, jc={'right': 'right', 'center': 'center'}.get(kind), bold=kind in ('bold', 'center'))
    write_docx(HERE / 'letterhead-declaration.docx', body, title='Dichiarazione di disponibilità alla fornitura',
               modified='2026-05-06T08:30:00Z', created='2026-05-05T15:00:00Z', author='Paolo Zanetti',
               header=header, footer=footer, header_rels=[('rIdLogo', 'image', 'media/logo.png')],
               media={'word/media/logo.png': logo})


# ---------- PDF ----------

def fixed_time(canvas, when):
    ts = canvas._doc._timeStamp
    ts.YMDhms = when.timetuple()[:6]
    ts.dhh, ts.dmm = 1, 0


def letterhead_pdf(logo):
    """The letterhead declaration as printed to PDF: same text, logo in the header, footer at the bottom."""
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.lib.enums import TA_JUSTIFY, TA_RIGHT, TA_CENTER, TA_LEFT
    from reportlab.lib.units import cm
    from reportlab.lib.utils import ImageReader
    from reportlab.platypus import SimpleDocTemplate, Paragraph

    def page(c, doc):
        fixed_time(c, dt.datetime(2026, 5, 6, 10, 45))
        c.drawImage(ImageReader(io.BytesIO(logo)), 2 * cm, A4[1] - 1 * cm - LOGO_CM[1] * cm, LOGO_CM[0] * cm, LOGO_CM[1] * cm)
        c.setFont('Helvetica', 8)
        c.setFillGray(.35)
        for k, line in enumerate(LETTER_FOOTER):
            c.drawCentredString(A4[0] / 2, 1.4 * cm - k * 11, line)

    base = ParagraphStyle('b', fontName='Helvetica', fontSize=11, leading=15, spaceAfter=8, alignment=TA_JUSTIFY)
    styles = {'': base, 'right': ParagraphStyle('r', base, alignment=TA_RIGHT, spaceAfter=2),
              'center': ParagraphStyle('c', base, alignment=TA_CENTER, fontName='Helvetica-Bold'),
              'bold': ParagraphStyle('o', base, alignment=TA_LEFT, fontName='Helvetica-Bold', spaceBefore=14)}
    doc = SimpleDocTemplate(str(HERE / 'letterhead-declaration.pdf'), pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm,
                            topMargin=3.2 * cm, bottomMargin=2.5 * cm, title='Dichiarazione di disponibilità alla fornitura',
                            author='Paolo Zanetti', creator='Microsoft Word', invariant=1)
    doc.build([Paragraph(escape(text), styles[kind]) for kind, text in LETTER], onFirstPage=page, onLaterPages=page)


def mark(store, key):
    """Invisible flowable that records where it is drawn (page index, x, y), to place the signature boxes."""
    from reportlab.platypus import Flowable

    class Mark(Flowable):
        def wrap(self, aw, ah): return 0, 0
        def drawOn(self, canvas, x, y, _sW=0): store[key] = (canvas.getPageNumber() - 1, x, y)
    return Mark()


def agreement_pdf(path, version, when, marks):
    """Commission agreement: header and 'Pagina n di m' footer on each page, signature lines at the end."""
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.lib.enums import TA_JUSTIFY, TA_CENTER
    from reportlab.lib.units import cm
    from reportlab.pdfgen.canvas import Canvas
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether

    class Numbered(Canvas):
        def __init__(self, *a, **k):
            super().__init__(*a, **k)
            self._pages = []
            fixed_time(self, when)

        def showPage(self):
            self._pages.append(dict(self.__dict__))
            self._startPage()

        def save(self):
            for i, state in enumerate(self._pages):
                self.__dict__.update(state)
                self.setFont('Helvetica', 8.5)
                self.setFillGray(.35)
                self.drawString(2.2 * cm, A4[1] - 1.3 * cm, AGREEMENT_HEADER)
                self.line(2.2 * cm, A4[1] - 1.45 * cm, A4[0] - 2.2 * cm, A4[1] - 1.45 * cm)
                self.drawCentredString(A4[0] / 2, 1.3 * cm, f'Pagina {i + 1} di {len(self._pages)}')
                super().showPage()
            super().save()

    pick = lambda s: re.sub(r'\{([^|}]*)\|([^}]*)\}', lambda m: m.group(version), s)
    base = ParagraphStyle('b', fontName='Times-Roman', fontSize=11.5, leading=16, spaceAfter=9, alignment=TA_JUSTIFY)
    head = ParagraphStyle('h', base, fontName='Times-Bold', spaceBefore=6, spaceAfter=3, keepWithNext=1)
    title = ParagraphStyle('t', base, fontName='Times-Bold', fontSize=16, alignment=TA_CENTER, spaceAfter=18)
    story = [Paragraph(AGREEMENT_TITLE, title)] + [Paragraph(escape(p), base) for p in AGREEMENT_PARTIES]
    for h, p in AGREEMENT:
        story += [Paragraph(escape(h), head), Paragraph(escape(pick(p)), base)]
    sign = Table([['Il committente', 'Il procacciatore'], ['Luca Bianchi', 'Mario Rossi'], ['', ''],
                  ['______________________________', '______________________________']],
                 colWidths=[8 * cm, 8 * cm], rowHeights=[16, 16, 2.2 * cm, 16])
    sign.setStyle(TableStyle([('FONT', (0, 0), (-1, -1), 'Times-Roman', 11.5), ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                              ('VALIGN', (0, 0), (-1, -1), 'TOP'), ('LEFTPADDING', (0, 0), (-1, -1), 0)]))
    story += [Spacer(1, 10), KeepTogether([Paragraph(AGREEMENT_PLACE, base), Spacer(1, 6), mark(marks, 'sig'), sign])]
    doc = SimpleDocTemplate(str(path), pagesize=A4, leftMargin=2.5 * cm, rightMargin=2.5 * cm, topMargin=2.4 * cm,
                            bottomMargin=2.4 * cm, title=AGREEMENT_TITLE, author='Ceramiche Lunardi S.r.l.', invariant=1)
    doc.build(story, canvasmaker=Numbered)


# ---------- signatures ----------

def certificates():
    """A throwaway test CA and two signer certificates, with keys derived from fixed numbers (reproducible)."""
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.x509.oid import NameOID

    name = lambda cn, org: x509.Name([x509.NameAttribute(NameOID.COUNTRY_NAME, 'IT'),
                                      x509.NameAttribute(NameOID.ORGANIZATION_NAME, org),
                                      x509.NameAttribute(NameOID.COMMON_NAME, cn)])
    start, end = dt.datetime(2026, 1, 1, tzinfo=dt.timezone.utc), dt.datetime(2036, 1, 1, tzinfo=dt.timezone.utc)
    ca_key = ec.derive_private_key(0xC0FFEE01, ec.SECP256R1())
    ca_name = name('Firme di Prova CA', 'Autorita di certificazione di prova')

    def cert(subject, key, serial, issuer_key, ca):
        b = (x509.CertificateBuilder().subject_name(subject).issuer_name(ca_name).public_key(key.public_key())
             .serial_number(serial).not_valid_before(start).not_valid_after(end)
             .add_extension(x509.BasicConstraints(ca=ca, path_length=None), critical=True))
        if not ca:
            b = b.add_extension(x509.KeyUsage(True, True, False, False, False, False, False, False, False), critical=True)
        return b.sign(issuer_key, hashes.SHA256())

    ca = cert(ca_name, ca_key, 1, ca_key, True)
    out = {}
    for k, (cn, org) in enumerate([('Luca Bianchi', 'Ceramiche Lunardi S.r.l.'), ('Mario Rossi', 'Mario Rossi')]):
        key = ec.derive_private_key(0xC0FFEE10 + k, ec.SECP256R1())
        out[cn] = (cert(name(cn, org), key, 100 + k, ca_key, False), key)
    pem = lambda c: c.public_bytes(serialization.Encoding.DER)
    der_key = lambda k: k.private_bytes(serialization.Encoding.DER, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())
    return {cn: (pem(c), der_key(k), pem(ca)) for cn, (c, k) in out.items()}


def sign(src, dst, cn, cert, field, box, page, when):
    from asn1crypto import keys, x509 as ax509
    from pyhanko.pdf_utils.incremental_writer import IncrementalPdfFileWriter
    from pyhanko.sign import fields, signers
    from pyhanko.stamp import TextStampStyle
    from pyhanko_certvalidator.registry import SimpleCertificateStore
    import pyhanko.sign.signers.pdf_signer as ps
    import pyhanko.pdf_utils.metadata.info as info

    leaf, key, ca = cert

    class Frozen(dt.datetime):
        @classmethod
        def now(cls, tz=None):
            return when.astimezone(tz) if tz else when.replace(tzinfo=None)
    ps.datetime, info.datetime = Frozen, Frozen   # fixed signing time and ModDate

    signer = signers.SimpleSigner(signing_cert=ax509.Certificate.load(leaf), signing_key=keys.PrivateKeyInfo.load(key),
                                  cert_registry=SimpleCertificateStore.from_certs([ax509.Certificate.load(ca)]))
    with open(src, 'rb') as f:
        w = IncrementalPdfFileWriter(f)
        fields.append_signature_field(w, fields.SigFieldSpec(sig_field_name=field, on_page=page, box=box))
        meta = signers.PdfSignatureMetadata(field_name=field, name=cn, reason='Sottoscrizione del contratto',
                                            location='Valdorso', md_algorithm='sha256')
        style = TextStampStyle(stamp_text='Firmato digitalmente da\n%(signer)s\n%(ts)s', timestamp_format='%d/%m/%Y %H:%M',
                               border_width=1)
        pdf_signer = signers.PdfSigner(meta, signer=signer, stamp_style=style)
        out = io.BytesIO()
        asyncio.run(pdf_signer.async_sign_pdf(w, output=out))
    dst.write_bytes(out.getvalue())


def agreements():
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import cm
    marks = {}
    agreement_pdf(HERE / 'agreement-v1.pdf', 1, dt.datetime(2026, 2, 3, 11, 0), {})
    agreement_pdf(HERE / 'agreement-v2.pdf', 2, dt.datetime(2026, 2, 17, 15, 0), marks)
    page, x, y = marks['sig']   # top-left corner of the signature table (x is the left margin)
    certs = certificates()
    top = y - 32   # below the 'Il committente' and name rows, in the empty cell above the signature lines
    left = (x + .5 * cm, top - 2.2 * cm + 4, x + 7.5 * cm, top - 6)
    right = (left[0] + 8 * cm, left[1], left[2] + 8 * cm, left[3])
    rome = dt.timezone(dt.timedelta(hours=1))
    sign(HERE / 'agreement-v2.pdf', HERE / 'agreement-v2-signed.pdf', 'Luca Bianchi', certs['Luca Bianchi'], 'FirmaCommittente',
         left, page, dt.datetime(2026, 2, 18, 9, 12, tzinfo=rome))
    sign(HERE / 'agreement-v2-signed.pdf', HERE / 'agreement-v2-countersigned.pdf', 'Mario Rossi', certs['Mario Rossi'],
         'FirmaProcacciatore', right, page, dt.datetime(2026, 2, 19, 17, 45, tzinfo=rome))


if __name__ == '__main__':
    image_pair()
    regulation()
    statute()
    logo = logo_png()
    letterhead_docx(logo)
    letterhead_pdf(logo)
    agreements()
    for f in sorted(HERE.glob('*.*')):
        if f.suffix in ('.docx', '.pdf'):
            print(f'{f.name:36} {f.stat().st_size:>8} bytes')
