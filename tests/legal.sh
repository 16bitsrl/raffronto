#!/bin/zsh
# Privacy policy and terms of use: four plain pages (Italian and English), in the sitemap, linked from the
# footer of every page of the app, in the same look and theme as the app.
# Usage: tests/legal.sh   (called by tests/e2e.sh; URL= to run it on another copy of the site)
set -u
URL=${URL:-http://diff-tracker.test/}
S="raff-legal-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
playwright-cli -s=$S open $URL >/dev/null
fail=0
run() { # name js-returning-'ok'
  local out
  out=$(playwright-cli -s=$S run-code "async page => { $2 }" 2>&1 | sed -n "/### Result/{n;p;}")
  if [[ $out == '"ok"' ]]; then echo "ok   $1"; else echo "FAIL $1: $out"; fail=1; fi
}
BASE=${URL%/}
# Italian path, English path, words of the title in each language
DOCS="const docs = [['/privacy/', '/en/privacy/', 'Informativa sulla privacy', 'Privacy policy'], ['/termini/', '/en/terms/', 'Termini di utilizzo', 'Terms of use']];"

run "privacy e termini: lingua, titolo, indirizzo ufficiale, versioni nelle due lingue, ritorno all'app" \
  "$DOCS const bad = []; for (const [it, en, tIt, tEn] of docs) for (const [path, lang, title, other, home] of [[it, 'it', tIt, en, '/'], [en, 'en', tEn, it, '/en/']]) { const res = await page.goto('$BASE' + path); const r = await page.evaluate(() => { const alt = Object.fromEntries([...document.querySelectorAll('link[rel=alternate][hreflang]')].map(l => [l.hreflang, l.href])); return { lang: document.documentElement.lang, title: document.title, h1: document.querySelector('h1')?.textContent, canonical: document.querySelector('link[rel=canonical]')?.href, alt, home: document.querySelector('a.brand')?.getAttribute('href'), switchTo: document.querySelector('footer a[hreflang]')?.getAttribute('href'), words: document.querySelector('main')?.innerText.split(/\\s+/).length, company: /16bit S\\.r\\.l\\./.test(document.body.innerText) }; }); const ok = res.status() === 200 && r.lang === lang && r.title.startsWith(title) && r.h1 === title && r.canonical === 'https://raffronto.app' + path && r.alt.it === 'https://raffronto.app' + it && r.alt.en === 'https://raffronto.app' + en && r.alt['x-default'] === 'https://raffronto.app' + en && r.home === home && r.switchTo === other && r.words > 150 && r.words < 900 && r.company; if (!ok) bad.push({ path, status: res.status(), ...r }); } return !bad.length ? 'ok' : JSON.stringify(bad);"

run "privacy e termini nella sitemap, con le versioni nelle due lingue" \
  "$DOCS const xml = await (await page.request.get('${BASE}/sitemap.xml')).text(); const missing = docs.flatMap(d => d.slice(0, 2)).filter(p => !xml.includes('<loc>https://raffronto.app' + p + '</loc>') || !xml.includes('hreflang=\"' + (p.startsWith('/en/') ? 'en' : 'it') + '\" href=\"https://raffronto.app' + p + '\"')); return !missing.length ? 'ok' : JSON.stringify(missing);"

run "a fondo pagina, su home e pagine per professione nelle due lingue: Privacy e Termini portano alla pagina giusta" \
  "const cases = [['/', 'Privacy', '/privacy/', 'Termini', '/termini/'], ['/avvocati/', 'Privacy', '/privacy/', 'Termini', '/termini/'], ['/en/', 'Privacy', '/en/privacy/', 'Terms', '/en/terms/'], ['/en/lawyers/', 'Privacy', '/en/privacy/', 'Terms', '/en/terms/']]; const bad = []; for (const [from, p, pHref, t, tHref] of cases) for (const [name, href] of [[p, pHref], [t, tHref]]) { await page.goto('$BASE' + from); const link = page.locator('footer.credit').getByRole('link', { name, exact: true }); const seen = await link.isVisible(); if (!seen) { bad.push({ from, name, seen }); continue; } await link.click(); await page.waitForURL('**' + href); const h1 = await page.locator('h1').textContent(); if (new URL(page.url()).pathname !== href || !h1) bad.push({ from, name, url: page.url() }); } return !bad.length ? 'ok' : JSON.stringify(bad);"

run "tema scuro scelto nell'app vale anche qui" \
  "await page.goto('$BASE/'); await page.evaluate(() => localStorage.setItem('raffronto-theme', 'dark')); await page.goto('$BASE/privacy/'); const dark = await page.evaluate(() => [document.documentElement.dataset.theme, getComputedStyle(document.body).backgroundColor, document.querySelector('h1')?.textContent]); await page.click('#themeBtn'); const light = await page.evaluate(() => [document.documentElement.dataset.theme, localStorage.getItem('raffronto-theme')]); await page.evaluate(() => localStorage.removeItem('raffronto-theme')); return dark[0] === 'dark' && dark[1] === 'rgb(22, 27, 38)' && dark[2] === 'Informativa sulla privacy' && light[0] === 'light' && light[1] === 'light' ? 'ok' : JSON.stringify({ dark, light });"

playwright-cli -s=$S close >/dev/null
exit $fail
