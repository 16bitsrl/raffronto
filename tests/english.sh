#!/bin/zsh
# The whole app in English (/en/): landing, comparison, list of changes, revisions, dialogs, menus, messages,
# print sheets and the Word download, with no Italian left in the interface. The documents in tests/fixtures
# are in Italian, so their content (pages, excerpts in the list, the test certificate authority) is left out of the scan.
# Usage: tests/english.sh   (called by tests/e2e.sh; URL= to run it on another copy of the site)
set -u
URL=${URL:-http://diff-tracker.test/}
EN=${URL}en/
FX=${0:A:h}/fixtures
S="raff-en-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
TMP=$(mktemp -d /tmp/raffronto-en-test.XXXXXX)
# sharing needs a secure page: on the local http site Chromium is told to treat it as one
print -r -- "{\"browser\":{\"launchOptions\":{\"args\":[\"--unsafely-treat-insecure-origin-as-secure=${URL%/}\"]}}}" > $TMP/pw.json
playwright-cli -s=$S open --config=$TMP/pw.json $EN >/dev/null
fail=0
run() { # name js-returning-'ok'
  local out
  out=$(playwright-cli -s=$S run-code "async page => { $2 }" 2>&1 | sed -n "/### Result/{n;p;}")
  if [[ $out == '"ok"' ]]; then echo "ok   $1"; else echo "FAIL $1: $out"; fail=1; fi
}
# Italian left in what is visible now, and in every title, label and placeholder of the page
SCAN="const scan = () => page.evaluate(() => { const FIXTURE = 'Firme di Prova CA'; const IT = /\\b(il|lo|gli|della|delle|degli|dei|nel|nella|sono|questo|questa|questi|modifich[ea]|pagin[ae]|document[oi]|version[ei]|nuov[ao]|originale|scarica|condividi|annulla|chiudi|inverti|riduci|ingrandisci|parol[ae]|aggiunt[ae]|tolt[ae]|firm[ae]|revision[ei]|accettate|rifiutate|capito|tutte|anche|oppure|perch|più|già|alle|ott|gen|giu|lug|dic|sinistra|destra|spostat[oi]|scorrere|sincronia|confronto|confronta)\\b|[àèéìòù]/i; const skip = '.page, .chg-body, script, style, svg, #printRoot'; const found = []; const walk = n => { for (const c of n.childNodes) { if (c.nodeType === 3) { const t = c.textContent.trim(); if (t && IT.test(t)) found.push(t.slice(0, 120)); } else if (c.nodeType === 1 && !c.matches(skip) && c.checkVisibility()) walk(c); } }; walk(document.body); for (const e of document.querySelectorAll('[title], [aria-label], [placeholder], [alt]')) { if (e.closest('.page, .chg-body, #printRoot')) continue; for (const a of ['title', 'aria-label', 'placeholder', 'alt']) { const v = e.getAttribute(a); if (v && IT.test(v.replaceAll(FIXTURE, ''))) found.push(a + ': ' + v.slice(0, 120)); } } if (IT.test(document.title)) found.push('title: ' + document.title); return [...new Set(found)]; });"
LOAD="const load = async (a, b) => { await page.goto('$EN'); const ins = page.locator('.drop input'); await ins.nth(0).setInputFiles(a); await ins.nth(1).setInputFiles(b); await page.waitForFunction(() => !document.querySelector('#ws').hidden || !document.querySelector('#dlg').hidden, null, { timeout: 30000 }); await page.waitForTimeout(800); };"
seen() { echo "const r = await scan(); return r.length ? JSON.stringify(r) : 'ok';"; }

run "pagina iniziale in inglese" \
  "$SCAN await page.goto('$EN'); const lang = await page.evaluate(() => document.documentElement.lang); if (lang !== 'en') return 'lang ' + lang; $(seen)"

run "un file caricato, in attesa dell'altro" \
  "$SCAN await page.goto('$EN'); await page.locator('.drop input').nth(0).setInputFiles('$FX/regulation-v1.docx'); await page.waitForTimeout(800); $(seen)"

run "confronto word: barra, intestazioni con le date, elenco e filtri" \
  "$SCAN $LOAD await load('$FX/regulation-v1.docx', '$FX/regulation-v2.docx'); const n = await page.evaluate(() => window.__raffronto.hunks.length); if (n !== 55) return 'hunks ' + n; await page.locator('.pane[data-side=\"1\"] mark.mk').nth(3).hover(); await page.waitForTimeout(300); $(seen)"

run "confronto pdf con firme" \
  "$SCAN $LOAD await load('$FX/agreement-v2.pdf', '$FX/agreement-v2-countersigned.pdf'); await page.locator('.pane-head').first().hover(); $(seen)"

run "revisioni di word: selettore, spiegazione, rifiutate" \
  "$SCAN $LOAD await page.goto('$EN'); await page.evaluate(() => localStorage.removeItem('raffronto-revisions-hint')); await load('$FX/statute-revisions.docx', '$FX/statute.docx'); const hint = await page.locator('#revHint').isVisible(); if (!hint) return 'no hint'; const a = await scan(); await page.getByRole('button', { name: 'Rejected' }).click(); await page.waitForTimeout(1200); const b = await scan(); const r = [...a, ...b]; return r.length ? JSON.stringify(r) : 'ok';"

run "documenti diversi: avviso" \
  "$SCAN $LOAD await load('$FX/regulation-v1.docx', '$FX/statute.docx'); if (await page.locator('#dlg').isHidden()) return 'no dialog'; $(seen)"

run "menu scarica, inverti, messaggi" \
  "$SCAN $LOAD await load('$FX/regulation-v1.docx', '$FX/regulation-v2.docx'); await page.locator('#printBtn').click(); await page.waitForTimeout(300); const a = await scan(); await page.keyboard.press('Escape'); await page.locator('#invertBtn').click(); await page.waitForTimeout(1500); const b = await scan(); const r = [...a, ...b]; return r.length ? JSON.stringify(r) : 'ok';"

run "fogli da stampare (pdf): intestazione, legenda, elenco" \
  "$LOAD await load('$FX/regulation-v1.docx', '$FX/regulation-v2.docx'); await page.evaluate(() => { window.print = () => {}; }); const r = {}; for (const layout of ['redline', 'both']) { await page.locator('#printBtn').click(); await page.locator('[data-layout=\"' + layout + '\"]').click(); await page.waitForTimeout(2500); r[layout] = await page.evaluate(() => { const IT = /\\b(modifich[ea]|pagin[ae]|parol[ae]|aggiunt[ae]|tolt[ae]|testo in comune|originale|nuova versione|sostituito|spostat[oi]|eliminazione|aggiunta|con modifiche|legenda)\\b/i; const root = document.querySelector('#printRoot'); const out = []; for (const e of root.querySelectorAll('*')) { if (e.closest('.page, .rl-page, canvas, .chg-body, .rl-note del')) continue; for (const c of e.childNodes) if (c.nodeType === 3 && IT.test(c.textContent)) out.push(c.textContent.trim().slice(0, 100)); } return { title: document.title, it: [...new Set(out)].slice(0, 12) }; }); await page.evaluate(() => dispatchEvent(new Event('afterprint'))); } const bad = Object.values(r).some(x => x.it.length || /con modifiche|originale|nuova versione/.test(x.title)); return bad ? JSON.stringify(r) : 'ok';"

run "word con revisioni: nome del file in inglese" \
  "$LOAD await load('$FX/regulation-v1.docx', '$FX/regulation-v2.docx'); await page.locator('#printBtn').click(); const [d] = await Promise.all([page.waitForEvent('download', { timeout: 20000 }), page.locator('[data-export=\"docx\"]').click()]); const name = d.suggestedFilename(); return /^regulation-v2 - .+\\.docx\$/.test(name) && !/con revisioni/.test(name) ? 'ok' : name;"

run "condivisione: richiesta di conferma e link non valido" \
  "$SCAN $LOAD await load('$FX/agreement-v1.pdf', '$FX/agreement-v2.pdf'); await page.locator('#shareBtn').click(); await page.waitForTimeout(300); const a = await scan(); await page.keyboard.press('Escape'); await page.goto('about:blank'); await page.goto('$EN#s=abc'); await page.waitForTimeout(1000); const b = await scan(); const r = [...a, ...b]; return r.length ? JSON.stringify(r) : 'ok';"

playwright-cli -s=$S close >/dev/null
rm -rf $TMP
exit $fail
