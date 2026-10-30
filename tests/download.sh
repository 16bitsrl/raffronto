#!/bin/zsh
# Desktop app download page (/scarica, /en/download): one big button for the visitor's system, guessed in the browser,
# the other versions of that system right under it, the note on the first launch, and every file in a list. Phones,
# tablets and unknown systems get the list and a line saying the web app works in the browser. Every link points
# to the latest GitHub release with a fixed file name. Each system is a separate browser context with its own
# user agent; navigator.userAgentData and the WebGL renderer (what Safari and Firefox on a Mac leave to tell
# Apple chips from Intel) are set before the page runs, as that browser would report them.
# Usage: tests/download.sh   (called by tests/e2e.sh; URL= to run it on another copy of the site)
set -u
URL=${URL:-http://diff-tracker.test/}
BASE=${URL%/}
S="raff-dl-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
playwright-cli -s=$S open $URL >/dev/null
fail=0
run() { # name js-returning-'ok'
  local out
  out=$(playwright-cli -s=$S run-code "async page => { $2 }" 2>&1 | sed -n "/### Result/{n;p;}")
  if [[ $out == '"ok"' ]]; then echo "ok   $1"; else echo "FAIL $1: $out"; fail=1; fi
}
REL=https://github.com/16bitsrl/raffronto/releases/latest/download/
FILES="const FILES = ['Raffronto-mac-arm64.dmg', 'Raffronto-mac-x64.dmg', 'Raffronto-windows-x64-setup.exe', 'Raffronto-windows-x64.msi', 'Raffronto-windows-arm64-setup.exe', 'Raffronto-linux-x64.AppImage', 'Raffronto-linux-x64.deb', 'Raffronto-linux-arm64.AppImage', 'Raffronto-linux-arm64.deb'];"
# visit(path, system): opens the page as that system would, returns what the visitor sees
VISIT="const visit = async (path, sys) => { const ctx = await page.context().browser().newContext({ userAgent: sys.ua, viewport: sys.mobile ? { width: 390, height: 844 } : { width: 1280, height: 900 }, isMobile: !!sys.mobile, hasTouch: !!sys.mobile }); await ctx.addInitScript(sys => { const uad = sys.uad && { platform: sys.uad.platform, mobile: !!sys.uad.mobile, brands: [{ brand: 'Chromium', version: '140' }], getHighEntropyValues: async () => ({ platform: sys.uad.platform, architecture: sys.uad.arch, bitness: '64', mobile: !!sys.uad.mobile }) }; Object.defineProperty(Navigator.prototype, 'userAgentData', { get: () => uad, configurable: true }); if (sys.gpu) for (const C of [WebGLRenderingContext, WebGL2RenderingContext]) { const get = C.prototype.getParameter; C.prototype.getParameter = function (p) { return p === 0x9246 ? sys.gpu : get.call(this, p); }; } }, sys); const p = await ctx.newPage(); try { await p.goto('$BASE' + path); await p.waitForFunction(() => document.documentElement.dataset.os, null, { timeout: 5000 }); return await p.evaluate(() => { const vis = e => !!e && e.checkVisibility(); const pick = [...document.querySelectorAll('.pick')].find(vis); return { os: document.documentElement.dataset.os, primary: pick?.querySelector('.primary')?.href ?? null, label: pick?.querySelector('.primary')?.innerText ?? null, more: pick ? [...pick.querySelectorAll('.more a')].map(a => a.href) : [], note: [...document.querySelectorAll('.first-run [data-for]')].filter(vis).map(e => e.dataset.for), browser: [...document.querySelectorAll('.in-browser')].some(vis), list: [...document.querySelectorAll('.all a[href*=\"/releases/latest/download/\"]')].filter(vis).map(a => a.href) }; }); } finally { await ctx.close(); } };"
CHROME_MAC='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
SAFARI_MAC='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15'
FIREFOX_MAC='Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:144.0) Gecko/20100101 Firefox/144.0'
CHROME_WIN='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
CHROME_LINUX='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
FIREFOX_LINUX_ARM='Mozilla/5.0 (X11; Linux aarch64; rv:144.0) Gecko/20100101 Firefox/144.0'
IPHONE='Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1'
ANDROID='Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36'
# system, what the browser reports, expected primary file, expected files right under it, expected first-launch note
CASES="const cases = [
  ['Mac con chip Apple, Chrome', { ua: '$CHROME_MAC', uad: { platform: 'macOS', arch: 'arm' } }, 'mac-arm64.dmg', ['mac-x64.dmg'], 'mac'],
  ['Mac Intel, Chrome', { ua: '$CHROME_MAC', uad: { platform: 'macOS', arch: 'x86' } }, 'mac-x64.dmg', ['mac-arm64.dmg'], 'mac'],
  ['Mac con chip Apple, Firefox', { ua: '$FIREFOX_MAC', gpu: 'Apple M1, or similar' }, 'mac-arm64.dmg', ['mac-x64.dmg'], 'mac'],
  ['Mac Intel, Firefox', { ua: '$FIREFOX_MAC', gpu: 'Intel(R) UHD Graphics 630, or similar' }, 'mac-x64.dmg', ['mac-arm64.dmg'], 'mac'],
  ['Mac, Safari (non dice il processore)', { ua: '$SAFARI_MAC', gpu: 'Apple GPU' }, 'mac-arm64.dmg', ['mac-x64.dmg'], 'mac'],
  ['Windows x64, Chrome', { ua: '$CHROME_WIN', uad: { platform: 'Windows', arch: 'x86' } }, 'windows-x64-setup.exe', ['windows-x64.msi', 'windows-arm64-setup.exe'], 'windows'],
  ['Windows ARM, Edge', { ua: '$CHROME_WIN', uad: { platform: 'Windows', arch: 'arm' } }, 'windows-arm64-setup.exe', ['windows-x64-setup.exe'], 'windows'],
  ['Linux x64, Chrome', { ua: '$CHROME_LINUX', uad: { platform: 'Linux', arch: 'x86' } }, 'linux-x64.AppImage', ['linux-x64.deb', 'linux-arm64.AppImage'], 'linux'],
  ['Linux ARM, Firefox', { ua: '$FIREFOX_LINUX_ARM' }, 'linux-arm64.AppImage', ['linux-arm64.deb', 'linux-x64.AppImage'], 'linux'],
  ['iPhone', { ua: '$IPHONE', mobile: true }, null, [], null],
  ['Android', { ua: '$ANDROID', mobile: true, uad: { platform: 'Android', arch: '', mobile: true } }, null, [], null],
];"

run "il pulsante principale scarica la versione per il sistema di chi visita, con le altre sotto e la nota sul primo avvio" \
  "$FILES $VISIT $CASES const bad = []; for (const path of ['/scarica', '/en/download']) for (const [name, sys, primary, more, note] of cases) { const r = await visit(path, sys); const want = primary && '${REL}Raffronto-' + primary; const ok = r.primary === want && more.every(m => r.more.includes('${REL}Raffronto-' + m)) && r.more.every(m => m.startsWith('${REL}')) && (note ? r.note.length === 1 && r.note[0] === note : true) && r.browser === !primary && r.list.length === FILES.length; if (!ok) bad.push({ path, name, ...r }); } return !bad.length ? 'ok' : JSON.stringify(bad);"

run "le due lingue: titolo, elenco di tutti i file con il nome fisso, note di rilascio, testi del pulsante" \
  "$FILES $VISIT const bad = []; for (const [path, lang, h1, label, all, notes] of [['/scarica', 'it', 'Raffronto per il tuo computer', 'Scarica per Mac', 'Tutte le versioni', 'Novità'], ['/en/download', 'en', 'Raffronto for your computer', 'Download for Mac', 'All versions', 'What’s new']]) { const r = await visit(path, { ua: '$CHROME_MAC', uad: { platform: 'macOS', arch: 'arm' } }); await page.goto('$BASE' + path); const d = await page.evaluate(() => ({ lang: document.documentElement.lang, h1: document.querySelector('h1').textContent, all: document.querySelector('.all h2')?.textContent, files: [...document.querySelectorAll('.all a[href*=\"/releases/latest/download/\"]')].map(a => a.href.split('/').pop()), notes: [...document.querySelectorAll('.all a')].find(a => a.href === 'https://github.com/16bitsrl/raffronto/releases/latest')?.textContent, text: document.body.innerText })); const italianLeft = lang === 'en' && /Scarica|Tutte|computer con|Impostazioni/.test(d.text); const ok = d.lang === lang && d.h1 === h1 && r.label?.includes(label) && d.all === all && FILES.every(f => d.files.includes(f)) && d.files.length === FILES.length && d.notes?.includes(notes) && !italianLeft; if (!ok) bad.push({ path, ...d, label: r.label, text: undefined, italianLeft }); } return !bad.length ? 'ok' : JSON.stringify(bad);"

run "a fondo pagina 'App per computer' / 'Desktop app' porta alla pagina giusta, anche da privacy e termini" \
  "const bad = []; for (const [from, name, to] of [['/', 'App per computer', '/scarica'], ['/avvocati', 'App per computer', '/scarica'], ['/privacy', 'App per computer', '/scarica'], ['/en', 'Desktop app', '/en/download'], ['/en/lawyers', 'Desktop app', '/en/download'], ['/en/terms', 'Desktop app', '/en/download']]) { await page.goto('$BASE' + from); const link = page.locator('footer').getByRole('link', { name, exact: true }); if (!(await link.isVisible())) { bad.push({ from, name, seen: false }); continue; } await link.click(); await page.waitForURL('**' + to); if (new URL(page.url()).pathname !== to) bad.push({ from, url: page.url() }); } return !bad.length ? 'ok' : JSON.stringify(bad);"

run "funzioni principali: 'Anche senza connessione' porta all'app per computer" \
  "const bad = []; for (const [from, to] of [['/', '/scarica'], ['/en', '/en/download']]) { await page.goto('$BASE' + from); const href = await page.locator('.promises a').getAttribute('href'); if (href !== to) bad.push({ from, href }); } return !bad.length ? 'ok' : JSON.stringify(bad);"

run "tema scuro anche qui, e da qui si torna all'app" \
  "await page.goto('$BASE/'); await page.evaluate(() => localStorage.setItem('raffronto-theme', 'dark')); await page.goto('$BASE/scarica'); const r = await page.evaluate(() => [document.documentElement.dataset.theme, getComputedStyle(document.body).backgroundColor, document.querySelector('a.brand').getAttribute('href')]); await page.evaluate(() => localStorage.removeItem('raffronto-theme')); return r[0] === 'dark' && r[1] === 'rgb(22, 27, 38)' && r[2] === '/' ? 'ok' : JSON.stringify(r);"

playwright-cli -s=$S close >/dev/null
exit $fail
