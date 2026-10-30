"""Builds the fixtures for the "Scarica PDF" checks: an old and a new version of the same short
contract, as .docx and as .pdf, with deletions, rewrites, additions and one moved paragraph.
Usage: uv run --with reportlab --with pillow tests/fixtures/make_print.py"""
import io, pathlib, zipfile
from xml.sax.saxutils import escape

HERE = pathlib.Path(__file__).parent

OLD = [
    "Contratto di fornitura di servizi",
    "1. Oggetto. Il fornitore si impegna a prestare al cliente i servizi descritti nell'allegato tecnico, con la massima diligenza e nel rispetto delle norme vigenti.",
    "2. Durata. Il contratto ha durata di dodici mesi dalla data di sottoscrizione e si rinnova tacitamente per periodi uguali, salvo disdetta inviata almeno sessanta giorni prima della scadenza.",
    "3. Corrispettivo. Il cliente paga un canone mensile anticipato entro il giorno dieci di ogni mese, mediante bonifico bancario sul conto indicato dal fornitore.",
    "4. Riservatezza. Le parti mantengono riservate tutte le informazioni ricevute durante l'esecuzione del contratto e non le comunicano a terzi senza consenso scritto.",
    "5. Responsabilità. Il fornitore risponde dei danni causati da dolo o colpa grave, entro il limite massimo del corrispettivo annuo.",
    "6. Recesso. Ciascuna parte può recedere con preavviso scritto di novanta giorni, senza penali, con comunicazione inviata per posta elettronica certificata.",
    "7. Dati personali. Il trattamento dei dati personali avviene nel rispetto del regolamento europeo e della normativa nazionale applicabile.",
    "8. Comunicazioni. Tutte le comunicazioni tra le parti si intendono validamente effettuate se inviate agli indirizzi indicati in premessa.",
    "9. Clausola penale. In caso di ritardo nella consegna il fornitore corrisponde una penale pari all'uno per cento del canone per ogni settimana di ritardo.",
    "10. Cessione. Il contratto non può essere ceduto a terzi senza il consenso scritto dell'altra parte, che non può essere irragionevolmente negato.",
    "11. Foro competente. Per ogni controversia relativa al presente contratto è competente in via esclusiva il foro di Milano.",
    "12. Disposizioni finali. Il presente contratto annulla e sostituisce ogni precedente accordo tra le parti sullo stesso oggetto.",
]
NEW = list(OLD)
NEW[2] = NEW[2].replace("di dodici mesi", "di ventiquattro mesi")                       # rewrite
NEW[3] = NEW[3].replace(" anticipato entro il giorno dieci di ogni mese,", "")          # deletion
NEW[5] = NEW[5] + " Resta esclusa ogni responsabilità per danni indiretti."             # addition
NEW.remove(OLD[9])                                                                       # deleted paragraph (9.)
NEW.remove(OLD[7])                                                                       # 7. Dati personali ...
NEW.insert(NEW.index(OLD[11]) + 1, OLD[7])                                               # ... moved after 11.
NEW[-1] = NEW[-1].replace("ogni precedente accordo", "ogni precedente accordo, scritto o verbale,")
PAGE_BREAK_AFTER = {5}   # index of the paragraph that ends page 1, in both versions

# ---------- docx ----------
W = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'

def docx(path, paras, size=(11906, 16838)):   # A4 by default, in twentieths of a point
    def p(t, i):
        br = '<w:p><w:r><w:br w:type="page"/></w:r></w:p>' if i in PAGE_BREAK_AFTER else ''
        rpr = '<w:rPr><w:b/><w:sz w:val="28"/></w:rPr>' if i == 0 else ''
        return f'<w:p><w:pPr><w:spacing w:after="160"/><w:jc w:val="both"/></w:pPr><w:r>{rpr}<w:t xml:space="preserve">{escape(t)}</w:t></w:r></w:p>{br}'
    body = ''.join(p(t, i) for i, t in enumerate(paras))
    sect = f'<w:sectPr><w:pgSz w:w="{size[0]}" w:h="{size[1]}"/><w:pgMar w:top="1418" w:right="1418" w:bottom="1418" w:left="1418" w:header="709" w:footer="709"/></w:sectPr>'
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>')
        z.writestr('_rels/.rels', '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>')
        z.writestr('word/document.xml', f'<?xml version="1.0" encoding="UTF-8"?><w:document {W}><w:body>{body}{sect}</w:body></w:document>')

# ---------- pdf (embedded TrueType font and a small photo, like real documents) ----------
def pdf(path, paras):
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.lib.utils import ImageReader
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.platypus import SimpleDocTemplate, Paragraph, PageBreak, Spacer, Image
    from PIL import Image as PIL
    font = 'Helvetica'
    for name, f in (('Body', '/System/Library/Fonts/Supplemental/Arial.ttf'), ('Body', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')):
        if pathlib.Path(f).exists():
            pdfmetrics.registerFont(TTFont(name, f)); font = name; break
    photo = PIL.new('RGB', (480, 240))
    photo.putdata([(40 + x // 3, 90 + y // 3, 200 - x // 4) for y in range(240) for x in range(480)])
    buf = io.BytesIO(); photo.save(buf, 'JPEG', quality=85); buf.seek(0)
    style = ParagraphStyle('p', fontName=font, fontSize=11.5, leading=16, spaceAfter=9, alignment=4)
    title = ParagraphStyle('t', parent=style, fontSize=15, leading=20, alignment=0)
    flow = [Image(buf, width=6 * 28.35, height=3 * 28.35), Spacer(1, 12)]
    for i, t in enumerate(paras):
        flow.append(Paragraph(escape(t), title if i == 0 else style))
        if i in PAGE_BREAK_AFTER: flow.append(PageBreak())
    doc = SimpleDocTemplate(str(path), pagesize=A4, leftMargin=70, rightMargin=70, topMargin=70, bottomMargin=70, title='Contratto', author='Raffronto')
    doc.build(flow)

docx(HERE / 'print-old.docx', OLD)
docx(HERE / 'print-new.docx', NEW, (12240, 15840))   # US Letter: side by side, both pages must still share one scale
pdf(HERE / 'print-old.pdf', OLD)
pdf(HERE / 'print-new.pdf', NEW)
