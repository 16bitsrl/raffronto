#!/bin/zsh
# Pages for each profession and the two languages: every page is the full app, with its own address,
# title, preview and links to the same page in the other language; the language hint follows the browser.
# Usage: tests/pages.sh   (called by tests/e2e.sh; URL= to run it on another copy of the site)
set -u
URL=${URL:-http://diff-tracker.test/}
FX=${0:A:h}/fixtures
S="raff-pages-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
playwright-cli -s=$S open $URL >/dev/null
fail=0
run() { # name js-returning-'ok'
  local out
  out=$(playwright-cli -s=$S run-code "async page => { $2 }" 2>&1 | sed -n "/### Result/{n;p;}")
  if [[ $out == '"ok"' ]]; then echo "ok   $1"; else echo "FAIL $1: $out"; fail=1; fi
}
BASE=${URL%/}
# path in Italian, path in English, a few words of the opening in each language
PAIRS="const pairs = [['/', '/en', 'è cambiato', 'changed'], ['/avvocati', '/en/lawyers', 'articolo 7', 'clause 7'], ['/notai', '/en/notaries', 'atto da firmare', 'deed to sign'], ['/gare-e-appalti', '/en/tenders', 'rettificato', 'amended'], ['/traduttori', '/en/translators', 'Traduci solo', 'Translate only']];"

run "ogni pagina: lingua, titolo, indirizzo ufficiale, versioni nelle due lingue, anteprima" \
  "$PAIRS const bad = []; const titles = new Set(); for (const [it, en, wIt, wEn] of pairs) for (const [path, lang, word, other] of [[it, 'it', wIt, en], [en, 'en', wEn, it]]) { const res = await page.goto('$BASE' + path); const r = await page.evaluate(() => { const m = k => document.querySelector('meta[property=\"' + k + '\"]')?.content; const alt = Object.fromEntries([...document.querySelectorAll('link[rel=alternate][hreflang]')].map(l => [l.hreflang, l.href])); return { lang: document.documentElement.lang, title: document.title, h1: document.querySelector('.hero h1')?.textContent, canonical: document.querySelector('link[rel=canonical]')?.href, ogUrl: m('og:url'), img: m('og:image'), locale: m('og:locale'), alt, manifest: document.querySelector('link[rel=manifest]')?.getAttribute('href'), switchTo: document.querySelector('.credit a[hreflang]')?.getAttribute('href') }; }); titles.add(r.title); const ok = res.status() === 200 && r.lang === lang && r.h1.includes(word) && r.canonical === 'https://raffronto.app' + path && r.ogUrl === r.canonical && r.img === 'https://raffronto.app/' + (lang === 'it' ? 'social.png' : 'social-en.png') && r.locale === (lang === 'it' ? 'it_IT' : 'en_GB') && r.alt.it === 'https://raffronto.app' + it && r.alt.en === 'https://raffronto.app' + en && r.alt['x-default'] === 'https://raffronto.app' + en && r.manifest === (lang === 'it' ? '/manifest.webmanifest' : '/en/manifest.webmanifest') && r.switchTo === other; if (!ok) bad.push({ path, status: res.status(), ...r }); } return !bad.length && titles.size === 10 ? 'ok' : JSON.stringify({ bad, titles: titles.size });"

run "sitemap con tutte le pagine e le versioni nelle due lingue" \
  "$PAIRS const xml = await (await page.request.get('${BASE}/sitemap.xml')).text(); const missing = pairs.flat().filter(p => p.startsWith('/')).filter(p => !xml.includes('<loc>https://raffronto.app' + p + '</loc>') || !xml.includes('hreflang=\"' + (p.startsWith('/en') ? 'en' : 'it') + '\" href=\"https://raffronto.app' + p + '\"')); return !missing.length ? 'ok' : JSON.stringify(missing);"

run "pagina per professione: casi d'uso, collegamenti alle altre, e il confronto funziona lì" \
  "await page.goto('${BASE}/avvocati/'); const cards = await page.locator('.uses article').count(); const nav = await page.locator('.credit nav a').evaluateAll(as => as.map(a => [a.textContent, a.getAttribute('href'), a.getAttribute('aria-current')])); const ins = page.locator('.drop input'); await ins.nth(0).setInputFiles('$FX/agreement-v1.pdf'); await ins.nth(1).setInputFiles('$FX/agreement-v2.pdf'); await page.waitForFunction(() => !document.querySelector('#ws').hidden, null, { timeout: 30000 }); await page.waitForTimeout(800); const n = await page.evaluate(() => window.__raffronto.hunks.length); const uses = await page.locator('.uses').isVisible(); const want = JSON.stringify([['Avvocati', '/avvocati', 'page'], ['Notai', '/notai', null], ['Gare e appalti', '/gare-e-appalti', null], ['Traduttori', '/traduttori', null]]); return cards === 3 && JSON.stringify(nav) === want && n === 2 && !uses ? 'ok' : JSON.stringify({ cards, nav, n, uses });"

# the recap of the features with screenshots of the app, below the drop zones and after the cards of a profession
run "funzioni principali con le immagini dell'app: home e professione, nelle due lingue, temi chiaro e scuro" \
  "const bad = []; for (const [path, lang, title] of [['/', 'it', 'al suo posto'], ['/en', 'en', 'in its place'], ['/avvocati', 'it', 'al suo posto'], ['/en/lawyers', 'en', 'in its place']]) for (const theme of ['light', 'dark']) { await page.goto('$BASE' + path); await page.evaluate(t => localStorage.setItem('raffronto-theme', t), theme); await page.reload(); const f = page.locator('#landing .features'); const r = { path, theme, visible: await f.isVisible(), siteOnly: await f.evaluate(e => e.classList.contains('site-only')), h2: await f.locator('h2').textContent(), items: await f.locator('h3').count() }; r.afterDrops = await page.evaluate(() => !!(document.querySelector('.drops').compareDocumentPosition(document.querySelector('.features')) & Node.DOCUMENT_POSITION_FOLLOWING)); r.afterUses = await page.evaluate(() => { const u = document.querySelector('.uses'); return !u || !!(u.compareDocumentPosition(document.querySelector('.features')) & Node.DOCUMENT_POSITION_FOLLOWING); }); const imgs = f.locator('img:visible'); r.imgs = await imgs.count(); r.loaded = []; for (let i = 0; i < r.imgs; i++) { const img = imgs.nth(i); await img.scrollIntoViewIfNeeded(); await img.evaluate(e => e.complete && e.naturalWidth ? 0 : new Promise(ok => { e.onload = e.onerror = ok; })); r.loaded.push(await img.evaluate(e => [e.naturalWidth > 0, e.getAttribute('src'), !!e.alt.trim(), e.loading, e.width > 0 && e.height > 0])); } const ok = r.visible && r.siteOnly && r.h2.includes(title) && r.items >= 4 && r.afterDrops && r.afterUses && r.imgs >= 4 && r.loaded.every(([w, src, alt, lazy, size]) => w && src.includes('-' + lang + '-' + theme + '.') && alt && lazy === 'lazy' && size); if (!ok) bad.push(r); } await page.evaluate(() => localStorage.removeItem('raffronto-theme')); return bad.length ? JSON.stringify(bad) : 'ok';"

run "funzioni principali nascoste durante il confronto" \
  "const r = {}; for (const path of ['/', '/en/lawyers']) { await page.goto('$BASE' + path); const before = await page.locator('.features').isVisible(); const ins = page.locator('.drop input'); await ins.nth(0).setInputFiles('$FX/agreement-v1.pdf'); await ins.nth(1).setInputFiles('$FX/agreement-v2.pdf'); await page.waitForFunction(() => !document.querySelector('#ws').hidden, null, { timeout: 30000 }); r[path] = [before, await page.locator('.features').isVisible()]; } return Object.values(r).every(([b, d]) => b && !d) ? 'ok' : JSON.stringify(r);"

run "manifest in inglese: si apre sulla pagina inglese" \
  "const m = await (await page.request.get('${BASE}/en/manifest.webmanifest')).json(); const it = await (await page.request.get('${BASE}/manifest.webmanifest')).json(); return m.lang === 'en' && m.start_url === '/en' && it.lang === 'it' && it.start_url === '/' && m.icons.every(i => i.src.startsWith('/')) ? 'ok' : JSON.stringify({ m, it });"

# a browser in another language: a separate context, with its own language and storage
HINT="const visit = async (locale, path, fn) => { const ctx = await page.context().browser().newContext({ locale }); const p = await ctx.newPage(); try { await p.goto('$BASE' + path); return await fn(p); } finally { await ctx.close(); } }; const shown = p => p.locator('#langHint').isVisible();"
run "browser in inglese sulla pagina italiana: invito alla versione inglese, che resta scelta" \
  "$HINT const r = await visit('en-US', '/avvocati', async p => { const first = await shown(p); const link = p.locator('#langHint a'); const text = await link.textContent(); await link.click(); await p.waitForURL('**/en/lawyers'); const onEn = await shown(p); await p.goto('$BASE/'); const later = await shown(p); return { first, text, onEn, later }; }); return r.first && /also available in English/.test(r.text) && !r.onEn && !r.later ? 'ok' : JSON.stringify(r);"

run "browser in italiano: niente invito sull'italiano, invito sulla pagina inglese" \
  "$HINT const it = await visit('it-IT', '/', shown); const en = await visit('it-IT', '/en/notaries', async p => ({ shown: await shown(p), text: await p.locator('#langHint a').textContent(), href: await p.locator('#langHint a').getAttribute('href') })); const de = await visit('de-DE', '/', shown); return !it && en.shown && /disponibile anche in italiano/.test(en.text) && en.href === '/notai' && de ? 'ok' : JSON.stringify({ it, en, de });"

run "chiudere l'invito alla lingua: resta chiuso anche alla visita dopo" \
  "$HINT const r = await visit('en-US', '/notai', async p => { const first = await shown(p); await p.locator('#langHintClose').click(); const after = await shown(p); await p.goto('$BASE/avvocati'); const later = await shown(p); return { first, after, later }; }); return r.first && !r.after && !r.later ? 'ok' : JSON.stringify(r);"

run "pulsante scarica l'app in alto: va alla pagina giusta, sparisce durante il confronto" \
  "const r = {}; for (const [path, want] of [['/', '/scarica'], ['/en/lawyers', '/en/download']]) { await page.goto('$BASE' + path); const b = page.locator('#getApp'); r[path] = { visible: await b.isVisible(), href: await b.getAttribute('href'), text: (await b.textContent()).trim() }; if (r[path].href !== want || !r[path].visible) return JSON.stringify(r); } const ins = page.locator('.drop input'); await ins.nth(0).setInputFiles('$FX/agreement-v1.pdf'); await ins.nth(1).setInputFiles('$FX/agreement-v2.pdf'); await page.waitForFunction(() => !document.querySelector('#ws').hidden, null, { timeout: 30000 }); const during = await page.locator('#getApp').isVisible(); return r['/'].text === 'Scarica l’app' && r['/en/lawyers'].text === 'Get the app' && !during ? 'ok' : JSON.stringify({ r, during });"

playwright-cli -s=$S close >/dev/null
exit $fail
