#!/bin/zsh
# What people see before using the app: link preview on social and chat apps, slogan, 16bit credit,
# search engine files, visit statistics (which must never receive the key of a shared link).
# Usage: tests/marketing.sh   (called by tests/e2e.sh; URL= to run it on another copy of the site)
set -u
URL=${URL:-http://diff-tracker.test/}
FX=${0:A:h}/fixtures
S="raff-mkt-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
playwright-cli -s=$S open $URL >/dev/null
fail=0
run() { # name js-returning-'ok'
  local out
  out=$(playwright-cli -s=$S run-code "async page => { $2 }" 2>&1 | sed -n "/### Result/{n;p;}")
  if [[ $out == '"ok"' ]]; then echo "ok   $1"; else echo "FAIL $1: $out"; fail=1; fi
}
SITE=https://raffronto.app/
SLOGAN='Ogni modifica, anche quella che non ti hanno detto.'

run "anteprima del link: titolo, slogan e immagine 1200x630" \
  "await page.goto('$URL'); const r = await page.evaluate(async () => { const m = k => document.querySelector('meta[property=\"' + k + '\"], meta[name=\"' + k + '\"]')?.content; const img = m('og:image'); let w = 0, h = 0, type = ''; if (img) { const res = await fetch(new URL(new URL(img).pathname.slice(1), location.href)); type = res.headers.get('content-type'); const b = await createImageBitmap(await res.blob()); w = b.width; h = b.height; } return { title: m('og:title'), desc: m('og:description'), url: m('og:url'), type: m('og:type'), site: m('og:site_name'), locale: m('og:locale'), img, alt: m('og:image:alt'), card: m('twitter:card'), w, h, mime: type }; }); return r.title && r.desc === '$SLOGAN' && r.url === '$SITE' && r.type === 'website' && r.site === 'Raffronto' && r.locale === 'it_IT' && r.img === '${SITE}social.png' && r.alt && r.card === 'summary_large_image' && r.w === 1200 && r.h === 630 && /png/.test(r.mime) ? 'ok' : JSON.stringify(r);"

run "slogan nella descrizione e a fondo pagina" \
  "await page.goto('$URL'); const desc = await page.locator('meta[name=description]').getAttribute('content'); const foot = page.locator('#landing footer'); const seen = await foot.getByText('$SLOGAN').isVisible(); return desc.startsWith('$SLOGAN') && seen ? 'ok' : JSON.stringify({ desc, seen });"

run "firma con il logo 16bit sulla pagina iniziale, non durante il confronto" \
  "await page.goto('$URL'); const a = page.getByRole('link', { name: 'Una trovata di 16bit' }); const r = { visible: await a.isVisible(), href: await a.getAttribute('href'), logo: await a.locator('img:visible').evaluate(i => i.naturalWidth) }; const ins = page.locator('.drop input'); await ins.nth(0).setInputFiles('$FX/agreement-v1.pdf'); await ins.nth(1).setInputFiles('$FX/agreement-v2.pdf'); await page.waitForFunction(() => !document.querySelector('#ws').hidden, null, { timeout: 30000 }); r.during = await a.isVisible(); return r.visible && r.href === 'https://16bit.it/' && r.logo > 0 && !r.during ? 'ok' : JSON.stringify(r);"

run "motori di ricerca: indirizzo ufficiale, robots, sitemap, scheda dell'app" \
  "await page.goto('$URL'); const r = await page.evaluate(async () => { const robots = await (await fetch('robots.txt')).text(); const sitemap = await (await fetch('sitemap.xml')).text(); let ld = null; try { ld = JSON.parse(document.querySelector('script[type=\"application/ld+json\"]').textContent); } catch {} return { canonical: document.querySelector('link[rel=canonical]')?.href, robots, sitemap, ld }; }); const ld = r.ld || {}; return r.canonical === '$SITE' && /^Sitemap: ${SITE//\//\\/}sitemap\.xml$/m.test(r.robots) && /User-agent: \*/.test(r.robots) && r.sitemap.includes('<loc>$SITE</loc>') && ld['@type'] === 'WebApplication' && ld.url === '$SITE' && ld.offers?.price === '0' && ld.creator?.name === '16bit' ? 'ok' : JSON.stringify(r);"

# Umami (third party, stats.16bit.cloud): the real script, the collection endpoint answered here.
# The page only counts visits on raffronto.app, so the test tells it this host is the one.
run "statistiche: visite e confronti contati, mai la chiave di un link condiviso" \
  "const ctx = page.context(); const sent = []; const host = new URL('$URL').hostname; await ctx.route('$URL', async r => { const res = await r.fetch(); r.fulfill({ response: res, body: (await res.text()).replace('data-domains=\"raffronto.app\"', 'data-domains=\"' + host + '\"') }); }); await ctx.route('https://stats.16bit.cloud/api/e', r => { sent.push(r.request().postData()); r.fulfill({ status: 200, contentType: 'application/json', body: '{}' }); }); await ctx.route('**/api/share?*', async r => { await new Promise(ok => setTimeout(ok, 3000)); r.fulfill({ status: 404, contentType: 'application/json', body: '{\"error\":\"not found\"}' }); }); const key = 'segretissimachiavedeltestnonvamaiinviata0001'.slice(0, 43); try { const tag = ((await (await page.request.get('$URL')).text()).match(/<script[^>]*stats\.16bit\.cloud[^>]*>/) || [''])[0]; await page.goto('about:blank'); await page.goto('$URL#s=' + 'ab'.repeat(16) + '.' + key); await page.waitForTimeout(2000); await page.getByRole('button', { name: 'Ho capito' }).click({ timeout: 5000 }); const ins = page.locator('.drop input'); await ins.nth(0).setInputFiles('$FX/agreement-v1.pdf'); await ins.nth(1).setInputFiles('$FX/agreement-v2.pdf'); await page.waitForFunction(() => !document.querySelector('#ws').hidden, null, { timeout: 30000 }); await page.waitForTimeout(1500); const ev = sent.map(s => JSON.parse(s)); const leak = sent.some(s => s.includes(key) || s.includes('#s=')); const views = ev.filter(e => !e.payload.name).length; const compare = ev.find(e => e.payload.name === 'compare'); const ok = /data-website-id=\"08ee6714-48bc-4c02-8be2-c13917b43212\"/.test(tag) && /data-exclude-hash=\"true\"/.test(tag) && views >= 1 && compare && compare.payload.data?.kind === 'pdf' && !leak; return ok ? 'ok' : JSON.stringify({ views, compare, leak, sent: sent.slice(0, 4) }); } finally { await ctx.unrouteAll(); }"

playwright-cli -s=$S close >/dev/null
exit $fail
