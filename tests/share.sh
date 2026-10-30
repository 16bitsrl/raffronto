#!/bin/zsh
# Share by link: the browser encrypts the comparison, the Worker (cloudflare/src/index.ts) stores only ciphertext for 7 days.
# Usage: tests/share.sh   (called by tests/e2e.sh). Runs the Worker locally with `cf dev` on port 8799 (started here if
# it is not running) and reads and edits its local storage (cloudflare/.wrangler), never the real one.
set -u
ROOT=${0:A:h:h}
FX=${0:A:h}/fixtures
URL=http://localhost:8799/
API=${URL}api/share
DEV=''
if ! curl -s -o /dev/null $URL; then
  (cd $ROOT/cloudflare && npx cf dev --port 8799 > /tmp/raffronto-cf-dev.log 2>&1) &
  DEV=$!
  for i in {1..60}; do curl -s -o /dev/null $URL && break; sleep 1; done
fi
# the app served by the Worker must be the current one
(cd $ROOT/cloudflare && node scripts/sync.mjs >/dev/null)
DB=$(ls $ROOT/cloudflare/.wrangler/state/v3/r2/miniflare-R2BucketObject/*.sqlite(N) | grep -v metadata | head -1)
sql() { sqlite3 $DB "$1"; }
fail=0
pass() { echo "ok   $1"; }
bad() { echo "FAIL $1: $2"; fail=1; }
created=()   # ids made by this run, removed at the end

# two tiny docx with tracked changes, built here so the test does not depend on personal files
TMP=$(mktemp -d /tmp/raffronto-share-test.XXXXXX)
mkdocx() { # path body-xml
  local d=$TMP/src-${1:t:r}
  mkdir -p $d/_rels $d/word
  print -r -- '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>' > "$d/[Content_Types].xml"
  print -r -- '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>' > $d/_rels/.rels
  print -r -- "<?xml version=\"1.0\" encoding=\"UTF-8\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>$2<w:sectPr/></w:body></w:document>" > $d/word/document.xml
  (cd $d && zip -q -X -r $1 '[Content_Types].xml' _rels word)
}
P() { print -r -- "<w:p><w:r><w:t xml:space=\"preserve\">$1</w:t></w:r></w:p>"; }
mkdocx $TMP/canone-revisioni.docx "<w:p><w:r><w:t xml:space=\"preserve\">Il canone annuo è di </w:t></w:r><w:del w:id=\"1\" w:author=\"Prova\"><w:r><w:delText>mille</w:delText></w:r></w:del><w:ins w:id=\"2\" w:author=\"Prova\"><w:r><w:t>duemila</w:t></w:r></w:ins><w:r><w:t xml:space=\"preserve\"> euro.</w:t></w:r></w:p>$(P 'Il contratto dura tre anni.')"
mkdocx $TMP/canone-finale.docx "$(P 'Il canone annuo è di mille euro.')$(P 'Il contratto dura tre anni.')$(P 'Il pagamento avviene entro marzo.')"
A=$TMP/canone-revisioni.docx B=$TMP/canone-finale.docx

S="raff-share-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
# encryption in the browser needs a secure page: the local site is plain http, so Chromium is told to trust it
print -r -- "{\"browser\":{\"launchOptions\":{\"args\":[\"--unsafely-treat-insecure-origin-as-secure=${URL%/}\"]}}}" > $TMP/pw.json
playwright-cli -s=$S open --config=$TMP/pw.json $URL >/dev/null
js() { playwright-cli -s=$S run-code "$1" 2>&1 | sed -n "/### Result/{n;p;}"; }
LOAD="await page.goto('$URL'); await page.evaluate(() => localStorage.setItem('raffronto-revisions-hint', '1')); const ins = page.locator('.drop input'); await ins.nth(0).setInputFiles('$A'); await ins.nth(1).setInputFiles('$B'); await page.waitForFunction(() => !document.querySelector('#ws').hidden, null, { timeout: 30000 }); await page.waitForTimeout(800);"
STATE="() => { const S = window.__raffronto; return JSON.stringify({ names: S.sides.map(s => s.file.name), n: S.hunks.length, modes: S.sides.map(s => s.mode) }); }"
# opens a link in a page of a new browser context (no shared storage), returns what that page shows
OPEN="const openFresh = async (link, fn) => { const b = page.context().browser(); const ctx = b ? await b.newContext() : page.context(); const p = await ctx.newPage(); await p.goto(link); await p.waitForFunction(() => !document.querySelector('#ws').hidden || !document.querySelector('#shareDlg').hidden, null, { timeout: 30000 }); await p.waitForTimeout(800); const r = await fn(p); await p.close(); if (b) await ctx.close(); return r; }; const notice = p => p.evaluate(() => ({ ws: !document.querySelector('#ws').hidden, landing: !document.querySelector('#landing').hidden, dlg: document.querySelector('#shareDlg').hidden ? '' : document.querySelector('#shareDlg').innerText }));"

# 1. create a link from a comparison (revisions rejected) and open it in a fresh browser
out=$(js "async page => { $LOAD $OPEN await page.getByRole('button', { name: 'Rifiutate' }).click(); await page.waitForTimeout(1000); const before = await page.evaluate($STATE); await page.click('#shareBtn'); const ask = await page.locator('#shareDlg').innerText(); await page.click('#shareGo'); await page.waitForFunction(() => document.querySelector('#shareLink').value, null, { timeout: 30000 }); const link = await page.inputValue('#shareLink'); const done = await page.locator('#shareDlg').innerText(); await page.context().grantPermissions(['clipboard-read', 'clipboard-write']).catch(() => {}); await page.click('#shareCopy'); await page.waitForTimeout(200); const copied = await page.evaluate(() => navigator.clipboard.readText()).catch(() => null); await page.click('#shareCancel'); await page.click('#shareBtn'); const again = await page.inputValue('#shareLink'); await page.click('#shareCancel'); const after = await openFresh(link, async p => ({ state: await p.evaluate($STATE), tag: await p.locator('#sharedTag').innerText(), hash: p.url().split('#')[1] || '' })); const ok = /nostro server/.test(ask) && /7 giorni/.test(ask) && /cifrat/.test(ask) && /^http:.*#s=[0-9a-f]{32}\\.[A-Za-z0-9_-]{43}$/.test(link) && /fino al/.test(done) && (copied === null || copied === link) && again === link && after.state === before && JSON.parse(before).modes.includes('reject') && /fino al/.test(after.tag); return ok ? 'ok ' + link : JSON.stringify({ ask, link, done, copied, again, before, after }); }")
link=${${out#\"}%\"}
if [[ $link == 'ok '* ]]; then link=${link#ok }; pass "condivisione: conferma, link, stesso confronto in un browser pulito"; else bad "condivisione" "$out"; link=''; fi
id=${${link#*\#s=}%%.*}
key=${link#*\#s=*.}
[[ -n $link ]] && created+=($id)

# 1b. whoever opens the link can download the two original files from the download menu; the creator does not see them
if [[ -n $link ]]; then
  out=$(js "async page => { $LOAD $OPEN const items = p => p.evaluate(() => [...document.querySelectorAll('#printMenu [data-original]')].filter(b => b.offsetParent).map(b => b.textContent)); await page.click('#printBtn'); const mine = await items(page); const got = await openFresh('$link', async p => { await p.click('#printBtn'); const shown = await items(p); const files = []; for (const i of [0, 1]) { const [d] = await Promise.all([p.waitForEvent('download'), p.click('#printMenu [data-original=\"' + i + '\"]')]); const path = '$TMP/dl-' + i; await d.saveAs(path); files.push({ name: d.suggestedFilename(), path }); if (!i) await p.click('#printBtn'); } return { shown, files }; }); return JSON.stringify({ mine, ...got }); }")
  out=${(Q)out}; out=${out//\\\"/\"}
  names=$(print -r -- $out | jq -r '.files | map(.name) | join(",")' 2>/dev/null)
  if [[ $(print -r -- $out | jq '.mine | length' 2>/dev/null) == 0 && $(print -r -- $out | jq '.shown | length' 2>/dev/null) == 2 && $names == "${A:t},${B:t}" ]] && cmp -s $TMP/dl-0 $A && cmp -s $TMP/dl-1 $B; then pass "chi apre il link scarica gli originali, identici"
  else bad "scarica originali" "$out"; fi
fi

# 2. the server keeps only ciphertext (what it sends back is what it stores)
blob=$TMP/blob.bin
if [[ -n $link ]] && curl -sf -o $blob "$API?id=$id"; then
  size=$(stat -f %z $blob); plain=$(( $(stat -f %z $A) + $(stat -f %z $B) ))
  if LC_ALL=C grep -q -a -F $'PK\x03\x04' $blob || LC_ALL=C grep -q -a -F 'word/document.xml' $blob || LC_ALL=C grep -q -a -F 'canone' $blob; then bad "archivio cifrato" "il file salvato contiene dati in chiaro"
  elif (( size <= plain )); then bad "archivio cifrato" "dimensione $size <= $plain"
  else pass "sul server solo dati cifrati ($size byte)"; fi
else bad "archivio cifrato" "link $id non scaricabile"; fi

# 3. a changed key or a broken link fails cleanly and leaves the start page
first=${key[1]}; [[ $first == A ]] && other=B || other=A
out=$(js "async page => { $OPEN const r = await openFresh('${URL}#s=$id.$other${key[2,-1]}', notice); const r2 = await openFresh('${URL}#s=../../etc/passwd', notice); return !r.ws && r.landing && /completo|modificato/.test(r.dlg) && !r2.ws && r2.landing && /non è valido|non funziona/.test(r2.dlg) ? 'ok' : JSON.stringify({ r, r2 }); }")
[[ $out == '"ok"' ]] && pass "chiave modificata e link rotto: messaggio chiaro" || bad "chiave modificata" "$out"

# 4. a file over 10 MB is refused before anything is uploaded
out=$(js "async page => { $LOAD let posts = 0; page.on('request', r => { if (r.method() === 'POST') posts++; }); await page.evaluate(() => { const s = window.__raffronto.sides[0]; s.file = new File([new Uint8Array(10_000_001)], s.file.name, { type: s.file.type, lastModified: s.file.lastModified }); }); await page.click('#shareBtn'); await page.waitForTimeout(300); const dlg = await page.locator('#shareDlg').innerText(); const go = await page.locator('#shareGo').isVisible(); return /10 MB/.test(dlg) && !go && posts === 0 ? 'ok' : JSON.stringify({ dlg, go, posts }); }")
[[ $out == '"ok"' ]] && pass "file oltre 10 MB rifiutato prima del caricamento" || bad "file troppo grande" "$out"

# 5. server-side checks with curl
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
c=$(head -c 20100000 /dev/zero | code -X POST -H 'Content-Type: application/octet-stream' --data-binary @- $API); [[ $c == 413 ]] && pass "server: corpo oltre il limite -> 413" || bad "server limite" "$c"
c=$(code -X POST -H 'Content-Type: text/plain' --data-binary 'ciao' $API); [[ $c == 415 ]] && pass "server: tipo sbagliato -> 415" || bad "server tipo" "$c"
c=$(code -X POST -H 'Content-Type: application/octet-stream' --data-binary '' $API); [[ $c == 400 ]] && pass "server: corpo vuoto -> 400" || bad "server vuoto" "$c"
c=$(code -X PUT $API); [[ $c == 405 ]] && pass "server: metodo sbagliato -> 405" || bad "server metodo" "$c"
bads=()
for q in '' 'id=' 'id=..%2F..%2Fetc%2Fpasswd' 'id=ABCDEF0123456789ABCDEF0123456789' 'id=0123' 'id=0123456789abcdef0123456789abcdeg' 'id[]=x' "id=$id%00"; do
  c=$(code "$API?$q"); [[ $c == 400 ]] || bads+=("$q:$c")
done
(( ${#bads} == 0 )) && pass "server: id non validi -> 400" || bad "server id" "${bads[*]}"
c=$(code "$API?id=00000000000000000000000000000000"); [[ $c == 404 ]] && pass "server: id inesistente -> 404" || bad "server inesistente" "$c"
c=$(code ${URL}api/altro); [[ $c == 404 ]] || bad "server" "api/altro risponde $c"
hdr=$(curl -s -D - -o $TMP/back.bin "$API?id=$id")
if [[ $hdr == *' 200'* && $hdr == *'application/octet-stream'* && $hdr == *'no-store'* && $hdr == *'nosniff'* ]] && cmp -s $TMP/back.bin $blob; then
  exp=$(print -r -- $hdr | sed -n 's/^[Xx]-[Ee]xpires: *\([0-9]*\).*/\1/p'); now=$(date +%s)
  (( exp > now + 7*86400 - 600 && exp <= now + 7*86400 )) && pass "server: download con tipo corretto e scadenza a 7 giorni" || bad "server scadenza" "$exp vs $now"
else bad "server download" "$hdr"; fi
post=$(curl -s -D $TMP/h -X POST -H 'Content-Type: application/octet-stream' --data-binary 'x' $API)
pid=$(print -r -- $post | sed -n 's/.*"id":"\([0-9a-f]*\)".*/\1/p'); [[ -n $pid ]] && created+=($pid)
[[ -n $pid && $(<$TMP/h) == *' 201'* && $(<$TMP/h) == *'application/json'* ]] && pass "server: caricamento -> 201 json" || bad "server caricamento" "$post"

# 6. expired links are refused at once (R2 then deletes them with a lifecycle rule, see docs)
if [[ -n $link ]]; then
  sql "update _mf_objects set custom_metadata = '{\"expires\":\"$(( $(date +%s) - 60 ))\"}' where key = 'blobs/$id'"
  c=$(code "$API?id=$id"); [[ $c == 410 ]] && pass "server: link scaduto -> 410" || bad "server scaduto" "$c"
  out=$(js "async page => { $OPEN const r = await openFresh('$link', notice); return !r.ws && r.landing && /scadut/.test(r.dlg) && /7 giorni/.test(r.dlg) ? 'ok' : JSON.stringify(r); }")
  [[ $out == '"ok"' ]] && pass "link scaduto: messaggio e pagina iniziale" || bad "link scaduto" "$out"
fi

# 7. per-address limit on new links (the counter of this computer is reset before and after)
sql "delete from _mf_objects where key like 'rate/%'"
codes=()
for i in {1..21}; do
  r=$(curl -s -w ' %{http_code}' -X POST -H 'Content-Type: application/octet-stream' --data-binary "r$i" $API)
  codes+=(${r##* }); n=$(print -r -- $r | sed -n 's/.*"id":"\([0-9a-f]*\)".*/\1/p'); [[ -n $n ]] && created+=($n)
done
[[ ${codes[20]} == 201 && ${codes[21]} == 429 ]] && pass "server: dopo 20 link in un'ora -> 429" || bad "server limite per indirizzo" "${codes[*]}"
sql "delete from _mf_objects where key like 'rate/%'"

# 8. the desktop app (another origin) may call the API
h=$(curl -s -D - -o /dev/null -X OPTIONS -H 'Origin: tauri://localhost' -H 'Access-Control-Request-Method: POST' -H 'Access-Control-Request-Headers: content-type' $API)
[[ $h == *' 204'* && $h == *'Access-Control-Allow-Origin: *'* && $h == *POST* ]] && pass "server: richieste da un'altra origine permesse" || bad "server cors" "$h"

for x in $created; do sql "delete from _mf_objects where key = 'blobs/$x'"; done
rm -rf $TMP
playwright-cli -s=$S close >/dev/null
[[ -n $DEV ]] && pkill -f "cf dev --port 8799" && pkill -f "wrangler.*8799"
exit $fail
