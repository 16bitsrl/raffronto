"""Builds the fixtures for the "Word con revisioni" download: a .docx pair, the new .docx with tracked
changes already in it, and a .pdf pair. Run: uv run tests/fixtures/make_tracked.py"""
import pathlib, zipfile

HERE = pathlib.Path(__file__).parent
NS = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
REV = 'w:author="Avvocato" w:date="2026-10-20T10:00:00Z"'


def esc(t):
    return t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def r(t, bold=False):
    rpr = '<w:rPr><w:b/></w:rPr>' if bold else ''
    return f'<w:r>{rpr}<w:t xml:space="preserve">{esc(t)}</w:t></w:r>'


def p(*runs, style=None, mark=''):
    ppr = f'<w:pStyle w:val="{style}"/>' if style else ''
    if mark or ppr:
        ppr = f'<w:pPr>{ppr}{mark}</w:pPr>'
    return f'<w:p>{ppr}{"".join(runs)}</w:p>'


def ins(i, *runs):
    return f'<w:ins w:id="{i}" {REV}>{"".join(runs)}</w:ins>'


def dele(i, t):
    return f'<w:del w:id="{i}" {REV}><w:r><w:delText xml:space="preserve">{esc(t)}</w:delText></w:r></w:del>'


def table(a, b):
    cell = lambda t: f'<w:tc><w:tcPr><w:tcW w:w="4500" w:type="dxa"/></w:tcPr>{p(r(t))}</w:tc>'
    return f'<w:tbl><w:tblPr><w:tblW w:w="9000" w:type="dxa"/><w:tblBorders><w:top w:val="single" w:sz="4"/><w:bottom w:val="single" w:sz="4"/><w:insideV w:val="single" w:sz="4"/></w:tblBorders></w:tblPr><w:tblGrid><w:gridCol w:w="4500"/><w:gridCol w:w="4500"/></w:tblGrid><w:tr>{cell(a)}{cell(b)}</w:tr></w:tbl>'


STYLES = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:styles {NS}>
<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/><w:sz w:val="22"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="160"/></w:pPr></w:pPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:pPr><w:jc w:val="center"/></w:pPr><w:rPr><w:b/><w:color w:val="1F4E79"/><w:sz w:val="36"/></w:rPr></w:style>
</w:styles>'''


def docx(path, body, header, footer):
    hdr = f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:hdr {NS}>{p(r(header))}</w:hdr>'
    ftr = f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:ftr {NS}>{p(r(footer))}</w:ftr>'
    sect = '<w:sectPr><w:headerReference w:type="default" r:id="rIdH"/><w:footerReference w:type="default" r:id="rIdF"/><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1417" w:right="1134" w:bottom="1134" w:left="1134" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>'
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/><Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/></Types>')
        z.writestr('_rels/.rels', '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>')
        z.writestr('word/_rels/document.xml.rels', '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rIdS" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rIdH" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/><Relationship Id="rIdF" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/></Relationships>')
        z.writestr('word/document.xml', f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document {NS}><w:body>{body}{sect}</w:body></w:document>')
        z.writestr('word/styles.xml', STYLES)
        z.writestr('word/header1.xml', hdr)
        z.writestr('word/footer1.xml', ftr)


TITLE = p(r('Contratto di fornitura'), style='Title')
OLD = TITLE + \
    p(r('Il fornitore si impegna a consegnare '), r('la merce', True), r(" entro trenta giorni dalla data dell'ordine.")) + \
    p(r('Il pagamento avviene con bonifico bancario a sessanta giorni.')) + \
    p(r('Questo paragrafo verrà eliminato nella nuova versione del contratto.')) + \
    p(r('Le parti possono recedere con un preavviso scritto di tre mesi.')) + \
    table('Prezzo', '100 euro') + p(r('Firmato dalle parti.'))
NEW = TITLE + \
    p(r('Il fornitore si impegna a consegnare '), r('la merce', True), r(" entro quindici giorni lavorativi dalla data dell'ordine.")) + \
    p(r('Il pagamento avviene con bonifico bancario a sessanta giorni.')) + \
    p(r('Il fornitore garantisce la qualità dei prodotti per '), r('due anni', True), r('.')) + \
    p(r('Le parti possono recedere con un preavviso di tre mesi.')) + \
    table('Prezzo', '120 euro') + p(r('Firmato dalle parti.'))
# the new version with tracked changes of its own: rejecting them gives NEW back
INS_MARK = f'<w:rPr><w:ins w:id="90" {REV}/></w:rPr>'
DEL_MARK = f'<w:rPr><w:del w:id="91" {REV}/></w:rPr>'
REVISED = TITLE + \
    p(r('Il fornitore si impegna a consegnare '), r('la merce', True), r(" entro quindici giorni lavorativi dalla data dell'ordine.")) + \
    p(r('Il pagamento avviene con bonifico '), dele(92, 'bancario '), r('a sessanta giorni.')) + \
    p(r('Il fornitore garantisce la qualità dei prodotti per '), r('due anni', True), r('.')) + \
    p(ins(93, r("Clausola aggiunta dall'avvocato durante la revisione.")), mark=INS_MARK) + \
    p(r('Le parti possono recedere '), mark=DEL_MARK) + \
    p(r('con un preavviso di '), dele(94, 'tre'), ins(95, r('sei')), r(' mesi.')) + \
    table('Prezzo', '120 euro') + p(r('Firmato dalle parti.'))

docx(HERE / 'tracked-old.docx', OLD, 'Studio Rossi, contratto di servizio', 'Documento riservato')
docx(HERE / 'tracked-new.docx', NEW, 'Studio Rossi, contratto di servizio', 'Documento riservato alle parti')
docx(HERE / 'tracked-new-revised.docx', REVISED, 'Studio Rossi, contratto di servizio', 'Documento riservato alle parti')


def pdf(path, pages):
    """pages: list of lists of (x, y, size, text); Helvetica, WinAnsi"""
    objs = ['<< /Type /Catalog /Pages 2 0 R >>', None, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>']
    kids = []
    for lines in pages:
        ops = ''.join(f'BT /F1 {s} Tf {x} {y} Td (' + t.encode('cp1252').decode('latin1').replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)') + ') Tj ET\n' for x, y, s, t in lines)
        data = ops.encode('latin1')
        objs.append(f'<< /Length {len(data)} >>\nstream\n'.encode('latin1') + data + b'endstream')
        objs.append(f'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents {len(objs)} 0 R >>')
        kids.append(len(objs))
    objs[1] = f'<< /Type /Pages /Kids [{" ".join(f"{k} 0 R" for k in kids)}] /Count {len(kids)} >>'
    out, offs = bytearray(b'%PDF-1.4\n'), []
    for i, o in enumerate(objs, 1):
        offs.append(len(out))
        out += f'{i} 0 obj\n'.encode() + (o if isinstance(o, bytes) else o.encode('latin1')) + b'\nendobj\n'
    x = len(out)
    out += f'xref\n0 {len(objs) + 1}\n0000000000 65535 f \n'.encode() + b''.join(f'{o:010d} 00000 n \n'.encode() for o in offs)
    out += f'trailer\n<< /Size {len(objs) + 1} /Root 1 0 R >>\nstartxref\n{x}\n%%EOF\n'.encode()
    path.write_bytes(out)


def page(n, total, paras):
    lines, y = [(72, 800, 9, 'Studio Rossi, contratto di servizio')], 760
    for para in paras:
        for i, t in enumerate(para):
            lines.append((72, y, 16 if t.isupper() else 11, t))
            y -= 22 if t.isupper() else 15
        y -= 12
    lines.append((72, 40, 9, f'Pagina {n} di {total}'))
    return lines


OLD_PDF = [
    [['CONTRATTO DI FORNITURA'],
     ['Il fornitore si impegna a consegnare la merce entro trenta giorni dalla data', "dell'ordine, presso la sede indicata dal cliente al momento della firma."],
     ['Il pagamento avviene con bonifico bancario a sessanta giorni dalla data della', 'fattura, salvo accordi diversi presi per iscritto tra le parti.'],
     ['Questo paragrafo verrà eliminato nella nuova versione del contratto.']],
    [['Le parti possono recedere con un preavviso scritto di tre mesi, da inviare con', 'raccomandata o posta certificata.'],
     ['Firmato dalle parti.']],
]
NEW_PDF = [
    [['CONTRATTO DI FORNITURA'],
     ['Il fornitore si impegna a consegnare la merce entro quindici giorni lavorativi dalla', "data dell'ordine, presso la sede indicata dal cliente al momento della firma."],
     ['Il pagamento avviene con bonifico bancario a sessanta giorni dalla data della', 'fattura, salvo accordi diversi presi per iscritto tra le parti.'],
     ['Il fornitore garantisce la qualità dei prodotti per due anni.']],
    [['Le parti possono recedere con un preavviso di tre mesi, da inviare con', 'raccomandata o posta certificata.'],
     ['Firmato dalle parti.']],
]
pdf(HERE / 'tracked-old.pdf', [page(i + 1, 2, ps) for i, ps in enumerate(OLD_PDF)])
pdf(HERE / 'tracked-new.pdf', [page(i + 1, 2, ps) for i, ps in enumerate(NEW_PDF)])
