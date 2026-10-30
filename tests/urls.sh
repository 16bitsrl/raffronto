#!/bin/zsh
# Page addresses without a trailing slash: every page answers 200 at its own address (no redirect), and its links,
# canonical, og:url, hreflang alternates and JSON-LD, the sitemap and the manifests use addresses without it.
# With the slash, Cloudflare redirects to the address without it (assets.htmlHandling "drop-trailing-slash"):
# checked on the given URL when it is not the local Herd site, and locally on the Worker run by `cf dev` (port 8799).
# Usage: tests/urls.sh   (called by tests/e2e.sh; URL= to run it on another copy of the site)
set -u
ROOT=${0:A:h:h}
URL=${URL:-http://diff-tracker.test/}
BASE=${URL%/}
S="raff-urls-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
PAGES=(/ /avvocati /notai /gare-e-appalti /traduttori /privacy /termini /scarica /en /en/lawyers /en/notaries /en/tenders /en/translators /en/privacy /en/terms /en/download)
fail=0
playwright-cli -s=$S open $URL >/dev/null
run() { # name js-returning-'ok'
  local out
  out=$(playwright-cli -s=$S run-code "async page => { $2 }" 2>&1 | sed -n "/### Result/{n;p;}; /### Error/{n;p;}")
  if [[ $out == '"ok"' ]]; then echo "ok   $1"; else echo "FAIL $1: $out"; fail=1; fi
}
JSPAGES="const pages = ['${(j:',':)PAGES}'];"
# a page address ends with a slash only if it is the home page
SLASHED="const slashed = u => { const x = new URL(u, '$URL'); return x.pathname !== '/' && x.pathname.endsWith('/'); };"

# Herd answers any unknown address with the home page: the page must also be the right one (its canonical)
run "ogni pagina risponde 200 al suo indirizzo senza barra finale, senza rimandi, con la pagina giusta" \
  "$JSPAGES const bad = []; for (const p of pages) { const res = await page.request.get('$BASE' + p, { maxRedirects: 0 }); const type = res.headers()['content-type'] || ''; const own = (await res.text()).includes('<link rel=\"canonical\" href=\"https://raffronto.app' + p + '\">'); if (res.status() !== 200 || !type.includes('text/html') || !own) bad.push({ p, status: res.status(), type, own }); } return !bad.length ? 'ok' : JSON.stringify(bad);"

run "in ogni pagina: indirizzo ufficiale, og:url, versioni, JSON-LD e collegamenti senza barra finale, e i collegamenti rispondono 200" \
  "$JSPAGES $SLASHED const bad = []; const targets = new Set(); for (const p of pages) { await page.goto('$BASE' + p); const r = await page.evaluate(() => { const ld = [...document.querySelectorAll('script[type=\"application/ld+json\"]')].map(s => JSON.parse(s.textContent).url).filter(Boolean); return { canonical: document.querySelector('link[rel=canonical]')?.href, og: document.querySelector('meta[property=\"og:url\"]')?.content, alt: [...document.querySelectorAll('link[rel=alternate][hreflang]')].map(l => l.href), ld, links: [...document.querySelectorAll('a[href]')].map(a => a.href).filter(h => h.startsWith(location.origin) || h.startsWith('https://raffronto.app/')) }; }); const want = 'https://raffronto.app' + p; if (r.canonical !== want || r.og !== want) bad.push({ p, canonical: r.canonical, og: r.og }); const all = [r.canonical, r.og, ...r.alt, ...r.ld, ...r.links].filter(Boolean); const wrong = all.filter(slashed); if (wrong.length) bad.push({ p, wrong }); if (r.alt.length !== 3) bad.push({ p, alt: r.alt }); for (const l of r.links) { const u = new URL(l); if (u.origin === new URL('$URL').origin) targets.add(u.pathname); } } for (const t of targets) { const res = await page.request.get('$BASE' + t, { maxRedirects: 0 }); if (res.status() !== 200) bad.push({ link: t, status: res.status() }); } return !bad.length ? 'ok' : JSON.stringify(bad);"

run "sitemap: tutte le pagine, senza barra finale" \
  "$JSPAGES $SLASHED const xml = await (await page.request.get('$BASE/sitemap.xml')).text(); const locs = [...xml.matchAll(/<loc>([^<]+)<\\/loc>/g)].map(m => m[1]); const hrefs = [...xml.matchAll(/href=\"([^\"]+)\"/g)].map(m => m[1]); const want = pages.map(p => 'https://raffronto.app' + p); const missing = want.filter(u => !locs.includes(u)); const extra = locs.filter(u => !want.includes(u)); const wrong = [...locs, ...hrefs].filter(slashed); return !missing.length && !extra.length && !wrong.length ? 'ok' : JSON.stringify({ missing, extra, wrong });"

run "manifest: l'app inglese si apre su /en" \
  "const it = await (await page.request.get('$BASE/manifest.webmanifest')).json(); const en = await (await page.request.get('$BASE/en/manifest.webmanifest')).json(); return it.start_url === '/' && it.id === '/' && en.start_url === '/en' && en.id === '/en' ? 'ok' : JSON.stringify({ it: [it.start_url, it.id], en: [en.start_url, en.id] });"

playwright-cli -s=$S close >/dev/null

# as Cloudflare serves them: each page at its address, and with the trailing slash a redirect to the address
# without it (Herd simply serves the page)
redirects() { # base
  local bad='' p got
  for p in $PAGES; do
    got=$(curl -s -w '\n%{http_code} %{redirect_url}' "$1$p")
    [[ ${got##*$'\n'} == '200 ' && $got == *"<link rel=\"canonical\" href=\"https://raffronto.app$p\">"* ]] || bad+=" $p → ${got##*$'\n'};"
    [[ $p == / ]] && continue
    got=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' "$1$p/")
    [[ $got == 30[178]\ $1$p ]] || bad+=" $p/ → $got;"
  done
  if [[ -z $bad ]]; then echo "ok   ogni pagina al suo indirizzo, e con la barra finale rimanda all'indirizzo senza ($1)"; else echo "FAIL indirizzi ($1):$bad"; fail=1; fi
}
if [[ $URL == http://diff-tracker.test/ ]]; then
  # the same site served locally by the Worker, as on Cloudflare
  CF=http://localhost:8799 DEV=''
  (cd $ROOT/cloudflare && node scripts/sync.mjs >/dev/null)
  if ! curl -s -o /dev/null $CF/; then
    (cd $ROOT/cloudflare && npx cf dev --port 8799 > /tmp/raffronto-cf-dev.log 2>&1) &
    DEV=$!
    for i in {1..60}; do curl -s -o /dev/null $CF/ && break; sleep 1; done
  fi
  redirects $CF
  [[ -n $DEV ]] && pkill -f "cf dev --port 8799" && pkill -f "wrangler.*8799"
else
  redirects $BASE
fi
exit $fail
