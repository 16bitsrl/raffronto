#!/bin/zsh
# No third party gets the visitor's address: in a real browser, the home page, a page for a profession, the legal
# pages and the download page, plus a PDF and a Word comparison, only ask the site itself (fonts and the PDF reader
# are served by us, app downloads go through /download/) and our own statistics (stats.16bit.cloud). Requests from
# the service worker count too (on https, where it runs). The pages themselves must not name a font or code CDN.
# Usage: tests/privacy-network.sh   (called by tests/e2e.sh; URL= to run it on another copy of the site)
set -u
URL=${URL:-http://diff-tracker.test/}
BASE=${URL%/}
FX=${0:A:h}/fixtures
S="raff-net-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
playwright-cli -s=$S open $URL >/dev/null
fail=0
run() { # name js-returning-'ok'
  local out
  out=$(playwright-cli -s=$S run-code "async page => { $2 }" 2>&1 | sed -n "/### Result/{n;p;}; /### Error/{n;p;}")
  if [[ $out == '"ok"' ]]; then echo "ok   $1"; else echo "FAIL $1: $out"; fail=1; fi
}
PAGES="const pages = ['/', '/avvocati', '/en', '/en/lawyers', '/privacy', '/en/terms', '/scarica', '/en/download'];"
# every http(s) request of the browser context (pages and service worker) that leaves the site and our statistics
WATCH="const seen = []; const ctx = page.context(); const on = r => seen.push(r.url()); ctx.on('request', on); const foreign = () => [...new Set(seen.filter(u => /^https?:/.test(u)).map(u => new URL(u)).filter(u => u.origin !== new URL('$URL').origin && u.origin !== 'https://stats.16bit.cloud').map(u => u.origin + u.pathname))];"
LOAD="const load = async (a, b) => { const ins = page.locator('.drop input'); await ins.nth(0).setInputFiles(a); await ins.nth(1).setInputFiles(b); await page.waitForFunction(() => !document.querySelector('#ws').hidden, null, { timeout: 30000 }); await page.waitForTimeout(800); return page.evaluate(() => window.__raffronto.hunks.length); };"

run "pagine e confronti pdf e word: nessuna richiesta fuori dal sito, tranne le nostre statistiche" \
  "$PAGES $WATCH $LOAD try { for (const p of pages) { await page.goto('$BASE' + p); await page.waitForLoadState('networkidle'); } await page.goto('$URL'); await page.waitForLoadState('networkidle'); const pdf = await load('$FX/agreement-v1.pdf', '$FX/agreement-v2.pdf'); await page.click('#newBtn'); await page.waitForTimeout(300); const docx = await load('$FX/regulation-v1.docx', '$FX/regulation-v2.docx'); await page.waitForTimeout(1000); const out = foreign(); return pdf === 2 && docx > 10 && !out.length ? 'ok' : JSON.stringify({ pdf, docx, foreign: out }); } finally { ctx.off('request', on); }"

run "caratteri e lettore pdf arrivano dal sito: Instrument Sans e Instrument Serif caricati, pdf.js dal sito" \
  "const bad = []; for (const p of ['/', '/en/lawyers', '/privacy', '/scarica']) { await page.goto('$BASE' + p); const r = await page.evaluate(async () => { await document.fonts.ready; await Promise.all(['16px \"Instrument Sans\"', '700 16px \"Instrument Sans\"', '16px \"Instrument Serif\"', 'italic 16px \"Instrument Serif\"'].map(f => document.fonts.load(f, 'Aàè'))); const loaded = [...document.fonts].filter(f => f.status === 'loaded').map(f => f.family.replace(/\"/g, '') + ' ' + f.style); const res = performance.getEntriesByType('resource').filter(e => /\\.woff2/.test(e.name)).map(e => new URL(e.name).origin); return { loaded, res, ui: getComputedStyle(document.body).fontFamily }; }); const own = r.res.length && r.res.every(o => o === new URL('$URL').origin); const fam = ['Instrument Sans normal', 'Instrument Serif normal', 'Instrument Serif italic'].every(f => r.loaded.includes(f)); if (!own || !fam) bad.push({ p, ...r }); } await page.goto('$URL'); $LOAD await load('$FX/agreement-v1.pdf', '$FX/agreement-v2.pdf'); const js = await page.evaluate(() => performance.getEntriesByType('resource').map(e => e.name).filter(n => /pdf(\\.worker)?\\.min\\.mjs/.test(n))); if (js.length < 2 || !js.every(n => n.startsWith('$BASE/vendor/pdfjs/'))) bad.push({ pdfjs: js }); return !bad.length ? 'ok' : JSON.stringify(bad);"

run "nelle pagine e nel service worker nessun indirizzo di Google Fonts, jsDelivr o dei file su GitHub" \
  "$PAGES const bad = []; for (const p of [...pages, '/sw.js', '/fonts/fonts.css']) { const res = await page.request.get('$BASE' + p); const text = await res.text(); const hits = text.match(/fonts\\.(googleapis|gstatic)\\.com|cdn\\.jsdelivr\\.net|unpkg\\.com|cdnjs|github\\.com\\/[^\"' ]*\\/releases\\/(latest\\/)?download/g); if (res.status() !== 200 || hits) bad.push({ p, status: res.status(), hits }); } return !bad.length ? 'ok' : JSON.stringify(bad);"

playwright-cli -s=$S close >/dev/null
exit $fail
