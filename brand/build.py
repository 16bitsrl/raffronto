"""Rigenera SVG, PNG e tavola. Solo risorse locali, nessuna richiesta di rete.

DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib UV_CACHE_DIR=/private/tmp/raffronto-uv \
uv run --with fonttools --with brotli --with cairosvg python brand/build.py
"""
from pathlib import Path
import base64
import json
import shutil
import xml.etree.ElementTree as ET
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
import cairosvg
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
INK, PAPER, NIGHT = '#203A59', '#F8F7F3', '#161B26'
SLOGAN = 'Ogni modifica, anche quella che non ti hanno detto.'

def wordmark(fontname, size, weight=None):
    font = TTFont(ROOT / 'fonts' / fontname)
    if weight:
        font = instantiateVariableFont(font, {'wght': weight}, inplace=True)
    glyphs, cmap = font.getGlyphSet(), font.getBestCmap()
    scale = size / font['head'].unitsPerEm
    pen = SVGPathPen(glyphs, ntos=lambda v: format(v, '.2f').rstrip('0').rstrip('.') if '.' in format(v, '.2f') else format(v, '.2f'))
    x = 0
    # Spaziatura ottica del solo marchio, indipendente dal sistema di rendering.
    corrections = {'Ra': -.025, 'af': -.008, 'ff': -.012, 'fr': -.010, 'ro': -.015, 'nt': -.008, 'to': -.020}
    previous = ''
    for char in 'Raffronto':
        x += corrections.get(previous + char, 0) * size
        name = cmap[ord(char)]
        glyphs[name].draw(TransformPen(pen, (scale, 0, 0, -scale, x, 0)))
        x += font['hmtx'][name][0] * scale
        previous = char
    return pen.getCommands(), x

def svg(content, viewbox, title, width=None, height=None):
    dims = f' width="{width}" height="{height}"' if width else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{viewbox}"{dims} role="img" aria-labelledby="title"><title id="title">{title}</title>{content}</svg>\n'

# Simboli disegnati a mano, non autotracciati dai bitmap esplorativi.
MARKS = {
 '01-fogli-nastro': '''<path d="M25 17V8H6V56H25V43H21V52H10V12H21V17Z M39 47V56H58V8H39V21H43V12H54V52H43V47Z"/>
 <path d="M17 23H24C36 23 31 35 43 35H47V43H42C28 43 33 31 23 31H17Z"/>''',
 '02-r-raccordo': '''<path fill-rule="evenodd" d="M12 56V8H34C46 8 52 14 52 25C52 33 48 38 41 40L55 56H42L24 35H31C38 35 42 32 42 25C42 19 39 17 34 17H22V46C22 52 18 56 12 56ZM27 19V31H31V19Z"/>''',
 '03-traccia': '''<path d="M6 8H28V26C20 20 14 23 6 28Z M6 36C15 30 20 28 28 34V54H6Z M36 10H58V30C50 36 44 38 36 32Z M36 40C44 46 50 42 58 38V56H36Z"/>'''
}
INFO = [
 ('01-fogli-nastro', 'Fogli e nastro', 'La direzione consigliata', 'Due fogli aperti e un nastro che cambia quota: il gesto centrale dell’app diventa il marchio.', 'Instrument Serif', 'instrument-serif.woff2', None),
 ('02-r-raccordo', 'R di raccordo', 'La firma più compatta', 'La R accoglie due margini nel suo occhiello. Più riconoscibile come iniziale, meno esplicita sul confronto.', 'Instrument Sans 560', 'instrument-sans.woff2', 560),
 ('03-traccia', 'Traccia', 'La sintesi più netta', 'Due fogli pieni attraversati da una traccia in negativo. Molto solida in piccolo, più astratta nel significato.', 'Instrument Sans 560', 'instrument-sans.woff2', 560)
]

def make_assets():
    out = ROOT / 'logo'
    out.mkdir(exist_ok=True)
    for ident, name, subtitle, description, typeface, font, weight in INFO:
        folder = out / ident
        folder.mkdir(exist_ok=True)
        mark = MARKS[ident]
        d, w = wordmark(font, 55 if weight is None else 48, weight)
        lockup_w = round(91 + w + 8)
        for variant, color in [('light', INK), ('dark', PAPER), ('mono', '#000000')]:
            (folder / f'symbol-{variant}.svg').write_text(svg(f'<g fill="{color}">{mark}</g>', '0 0 64 64', f'Raffronto, {name}, simbolo'))
            body = f'<g fill="{color}"><g transform="translate(4 8)">{mark}</g><path transform="translate(87 57)" d="{d}"/></g>'
            (folder / f'logo-{variant}.svg').write_text(svg(body, f'0 0 {lockup_w} 80', f'Raffronto, {name}', lockup_w, 80))
        # La variante per favicon usa bordi a pixel interi nella griglia 16 × 16.
        # I pieni del monogramma e della traccia sono già abbastanza robusti.
        favicon_mark = mark
        if ident == '01-fogli-nastro':
            favicon_mark = '<path d="M24 16V8H4V56H24V44H20V52H8V12H20V16Z M40 48V56H60V8H40V20H44V12H56V52H44V48Z M16 24H24C36 24 32 36 44 36H48V44H44C28 44 32 32 24 32H16Z"/>' 
        favicon = svg(f'<style>:root{{color:{INK}}}@media(prefers-color-scheme:dark){{:root{{color:{PAPER}}}}}</style><g fill="currentColor">{favicon_mark}</g>', '0 0 64 64', f'Raffronto, {name}, favicon', 16, 16)
        (folder / 'favicon.svg').write_text(favicon)
        for size in (16, 32):
            cairosvg.svg2png(bytestring=svg(f'<g fill="{INK}">{favicon_mark}</g>', '0 0 64 64', 'Raffronto').encode(), write_to=str(folder / f'favicon-{size}.png'), output_width=size, output_height=size)
        # Fondo pieno quadrato, il sistema operativo applica la propria maschera.
        # Il disegno è interamente nel cerchio di sicurezza maskable centrale.
        for variant, bg, fg in [('light', PAPER, INK), ('dark', INK, PAPER)]:
            app = svg(f'<path fill="{bg}" d="M0 0H512V512H0Z"/><g fill="{fg}" transform="translate(96 96) scale(5)">{mark}</g>', '0 0 512 512', f'Raffronto, {name}, icona app', 512, 512)
            (folder / f'app-{variant}.svg').write_text(app)
            for size in (192, 512):
                cairosvg.svg2png(bytestring=app.encode(), write_to=str(folder / f'app-{variant}-{size}.png'), output_width=size, output_height=size)

def inline_asset(ident, asset):
    return (ROOT / 'logo' / ident / asset).read_text().replace('id="title"', f'id="{ident}-{asset}"').replace('aria-labelledby="title"', f'aria-labelledby="{ident}-{asset}"')

def make_board():
    cards = []
    for ident, name, subtitle, desc, typeface, font, weight in INFO:
        symbol = inline_asset(ident, 'symbol-light.svg')
        light = inline_asset(ident, 'logo-light.svg')
        dark = inline_asset(ident, 'logo-dark.svg')
        mono = inline_asset(ident, 'logo-mono.svg')
        app = inline_asset(ident, 'app-dark.svg')
        fav = base64.b64encode((ROOT/'logo'/ident/'favicon-16.png').read_bytes()).decode()
        cards.append(f'''<article><header><span class="number">{ident[:2]}</span><h2>{name}</h2><p class="subtitle">{subtitle}</p></header>
        <div class="hero-symbol">{symbol}</div><p class="description">{desc}</p>
        <div class="spec"><div class="fav"><img src="data:image/png;base64,{fav}" width="16" height="16" alt="Favicon a 16 pixel"><span>Raffronto</span><span class="close">×</span></div><div class="app">{app}</div></div>
        <p class="caption">Favicon 16 × 16 · Icona da originale 512 × 512</p>
        <div class="bar light">{light}</div><div class="bar dark">{dark}</div>
        <div class="slogan">{SLOGAN}</div>
        <div class="mono">{mono}<span>Un solo inchiostro</span></div>
        <p class="caption">Logotipo: {typeface}</p><a href="logo/{ident}/logo-light.svg" download>Scarica SVG ↗</a></article>''')
    page = '''<!doctype html><html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Raffronto · tre direzioni per il marchio</title><style>
    *{box-sizing:border-box}html,body{margin:0}body{font:15px/1.5 system-ui,sans-serif;color:var(--foreground,#203A59)}main{max-width:1400px;margin:0 auto}h1{font-size:clamp(30px,5vw,58px);font-weight:500;line-height:1.08;letter-spacing:-.045em;margin:12px 0 16px} .intro{padding:24px 0 28px;border-bottom:1px solid var(--border,#D5DBE4)}.eyebrow,.number,.caption{font-size:12px}.eyebrow{letter-spacing:.06em}.intro p{max-width:720px;color:var(--muted-foreground,#5E6779)}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px;padding-top:24px}article{background:#F8F7F3;color:#203A59;padding:22px;border-radius:var(--radius,8px);min-width:0}h2{font-size:25px;letter-spacing:-.025em;margin:8px 0 0;font-weight:550}.subtitle{margin:3px 0 0;font-size:12px;color:#5E6779}.number{border-top:2px solid #203A59;padding-top:5px}.hero-symbol{height:185px;display:grid;place-items:center}.hero-symbol svg{width:136px;height:136px}.description{min-height:112px;margin:0 0 16px;font-size:14px}.spec{display:flex;align-items:center;justify-content:space-between;gap:8px}.fav{display:flex;gap:9px;align-items:center;background:#fff;border:1px solid #D5DBE4;border-radius:7px 7px 0 0;padding:9px;font-size:11px;min-width:0}.close{margin-left:18px;color:#8A93A5}.app svg{width:62px;height:62px;display:block;border-radius:14px}.caption{color:#5E6779;font-size:10px;margin:9px 0 20px}.bar{height:70px;padding:16px 12px;display:flex;align-items:center}.bar svg{width:100%;max-height:40px;display:block}.light{background:#fff;border:1px solid #D5DBE4}.dark{background:#161B26}.slogan{font-size:19px;letter-spacing:-.02em;line-height:1.3;padding:22px 0 26px;min-height:115px;max-width:290px}.mono{border-top:1px solid #D5DBE4;padding-top:18px}.mono svg{display:block;width:72%;height:40px}.mono span{font-size:10px;color:#5E6779}a{color:#203A59;font-size:12px;text-underline-offset:4px}footer{font-size:12px;color:var(--muted-foreground,#5E6779);padding:24px 0 32px;max-width:780px}.palette{display:flex;flex-wrap:wrap;gap:8px;margin-top:18px}.palette span{padding:7px 10px;border:1px solid var(--border,#D5DBE4);font-size:11px}.ink{background:#203A59;color:#F8F7F3}.paper{background:#F8F7F3;color:#203A59}@media(min-width:621px) and (max-width:900px){.close{display:none}.fav{gap:5px;font-size:10px;padding:9px 7px}}@media(max-width:620px){.grid{grid-template-columns:1fr}article{padding:22px}.description{min-height:0}.hero-symbol{height:170px}.slogan{min-height:0}.intro{padding-top:16px}}@media print{.grid{gap:12px}article{break-inside:avoid;padding:15px}a{display:none}*{-webkit-print-color-adjust:exact;print-color-adjust:exact}}
    </style></head><body><main><div class="intro"><div class="eyebrow">16bit / Raffronto / studio del marchio</div><h1>Il filo tra due versioni.</h1><p>Tre direzioni vettoriali nate da quattro esplorazioni. Il blu inchiostro firma il prodotto; rosso, verde e ambra continuano a raccontare le modifiche.</p><div class="palette"><span class="ink">Inchiostro #203A59</span><span class="paper">Carta #F8F7F3</span><span>Fondo scuro #161B26</span></div></div><section class="grid">'''+''.join(cards)+'''</section><footer>Consiglio: <strong>Fogli e nastro</strong>. Rende visibile il confronto senza ricorrere a simboli di settore. Il logotipo serif richiama la pagina scritta; il nastro porta nel marchio un gesto proprio dell’app.<br>Un progetto gratuito di studio 16bit. I documenti vengono confrontati nel browser.</footer></main></body></html>'''
    (ROOT / 'board.html').write_text(page)

def contact_sheet():
    canvas = Image.new('RGB', (1200, 670), PAPER)
    draw = ImageDraw.Draw(canvas)
    for n, (ident, name, *_) in enumerate(INFO):
        x = n * 400
        draw.text((x+25, 20), f'{n+1:02d}  {name}', fill=INK)
        for source, size, top in [('symbol-light.svg', 192, 65), ('logo-light.svg', 340, 290)]:
            image_path = ROOT / 'logo' / ident / source
            png = cairosvg.svg2png(bytestring=image_path.read_bytes(), output_width=size)
            import io
            im = Image.open(io.BytesIO(png)).convert('RGBA')
            canvas.paste(im, (x+(400-size)//2, top), im)
        icon = Image.open(ROOT/'logo'/ident/'app-dark-192.png').convert('RGBA')
        canvas.paste(icon, (x+104, 410), icon)
        favicon = Image.open(ROOT/'logo'/ident/'favicon-16.png').convert('RGBA')
        canvas.paste(favicon, (x+40, 380), favicon)
        draw.text((x+65, 380), '16 px', fill=INK)
    canvas.save(ROOT / 'logo' / 'comparison.png')

if __name__ == '__main__':
    make_assets()
    make_board()
    contact_sheet()
    files = list((ROOT/'logo').rglob('*.svg'))
    for path in files:
        tree = ET.parse(path)
        assert not tree.findall('.//{http://www.w3.org/2000/svg}text'), path
        assert not tree.findall('.//{http://www.w3.org/2000/svg}image'), path
    print(f'{len(files)} SVG verificati: nessun testo o bitmap incorporato.')
