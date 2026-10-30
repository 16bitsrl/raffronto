#!/bin/zsh
# Installable app: manifest with icons, service worker that keeps the page, pdf.js and the fonts for offline use.
# Usage: tests/pwa.sh   (called by tests/e2e.sh; URL= to run it on another copy of the site)
set -u
URL=${URL:-http://diff-tracker.test/}
FX=${0:A:h}/fixtures
S="raff-pwa-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
TMP=$(mktemp -d /tmp/raffronto-pwa-test.XXXXXX)
# service workers need a secure page: on the local http site Chromium is told to treat it as one
print -r -- "{\"browser\":{\"launchOptions\":{\"args\":[\"--unsafely-treat-insecure-origin-as-secure=${URL%/}\"]}}}" > $TMP/pw.json
playwright-cli -s=$S open --config=$TMP/pw.json $URL >/dev/null
fail=0
run() { # name js-returning-'ok'
  local out
  out=$(playwright-cli -s=$S run-code "async page => { $2 }" 2>&1 | sed -n "/### Result/{n;p;}")
  if [[ $out == '"ok"' ]]; then echo "ok   $1"; else echo "FAIL $1: $out"; fail=1; fi
}
READY="await page.evaluate(() => Promise.race([navigator.serviceWorker.ready, new Promise((_, no) => setTimeout(() => no(new Error('nessun service worker')), 5000))]));"
LOAD="const load = async (a, b) => { const ins = page.locator('.drop input'); await ins.nth(0).setInputFiles(a); await ins.nth(1).setInputFiles(b); await page.waitForFunction(() => !document.querySelector('#ws').hidden, null, { timeout: 30000 }); await page.waitForTimeout(800); return page.evaluate(() => window.__raffronto.hunks.length); };"

run "app installabile: manifest e icone" \
  "await page.goto('$URL'); const r = await page.evaluate(async () => { const l = document.querySelector('link[rel=manifest]'); if (!l) return { link: false }; const m = await (await fetch(l.href)).json(); const icons = await Promise.all(m.icons.filter(i => i.type === 'image/png').map(async i => { const res = await fetch(new URL(i.src, l.href)); const img = await createImageBitmap(await res.blob()); return { sizes: i.sizes, type: res.headers.get('content-type'), w: img.width, h: img.height, purpose: i.purpose || 'any' }; })); return { name: m.name, short: m.short_name, display: m.display, start: m.start_url, theme: !!m.theme_color, bg: !!m.background_color, icons, apple: !!document.querySelector('link[rel=apple-touch-icon]'), favicon: !!document.querySelector('link[rel=icon]'), metaTheme: !!document.querySelector('meta[name=theme-color]') }; }); const has = s => r.icons && r.icons.some(i => i.sizes === s + 'x' + s && i.w === s && i.h === s && /png/.test(i.type)); return r.name === 'Raffronto' && r.short === 'Raffronto' && r.display === 'standalone' && r.start && r.theme && r.bg && has(192) && has(512) && r.icons.some(i => /maskable/.test(i.purpose)) && r.apple && r.favicon && r.metaTheme ? 'ok' : JSON.stringify(r);"

run "service worker attivo sulla pagina" \
  "await page.goto('$URL'); $READY await page.reload(); const r = await page.evaluate(async () => ({ ctrl: !!navigator.serviceWorker.controller, caches: (await Promise.all((await caches.keys()).map(async k => (await (await caches.open(k)).keys()).map(q => q.url)))).flat() })); const has = s => r.caches.some(u => u.includes(s)); return r.ctrl && has('/vendor/pdfjs/') && has('pdf.min.mjs') && has('pdf.worker.min.mjs') && has('/fonts/fonts.css') && has('.woff2') && has('manifest.webmanifest') && !has('api/share') ? 'ok' : JSON.stringify(r);"

run "senza rete: la pagina si apre e confronta pdf e word" \
  "$LOAD await page.goto('$URL'); $READY await page.context().setOffline(true); try { await page.reload(); const title = await page.title(); const pdf = await load('$FX/agreement-v1.pdf', '$FX/agreement-v2.pdf'); await page.click('#newBtn'); await page.waitForTimeout(300); const docx = await load('$FX/regulation-v1.docx', '$FX/regulation-v2.docx'); return /Raffronto/.test(title) && pdf === 2 && docx > 10 ? 'ok' : JSON.stringify({ title, pdf, docx }); } finally { await page.context().setOffline(false); }"

run "con rete la pagina arriva sempre aggiornata dal server" \
  "await page.goto('$URL'); $READY const ctx = page.context(); await ctx.route('$URL', async r => { const res = await r.fetch(); r.fulfill({ response: res, body: (await res.text()).replace('<title>', '<title>nuova ') }); }); try { await page.reload(); const title = await page.title(); return /^nuova /.test(title) ? 'ok' : JSON.stringify({ title }); } finally { await ctx.unroute('$URL'); }"

playwright-cli -s=$S close >/dev/null
rm -rf $TMP
exit $fail
