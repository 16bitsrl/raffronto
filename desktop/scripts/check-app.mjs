// Checks the development build of the app (src-tauri/target/debug/raffronto) on the synthetic
// documents in ../tests/fixtures. The app is started with RAFFRONTO_DEBUG_PORT, the steps run
// inside the page through that port, and the results come back through the page console.
// Files reach the page as a drop event (the native file panel and a real drag need a person).
// Usage: node scripts/check-app.mjs [--print]   (--print also opens the print panel and waits for a person to save or cancel)
import { spawn, spawnSync } from 'node:child_process';
import { readFileSync, existsSync, mkdirSync, writeFileSync, renameSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import net from 'node:net';

const desktop = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const fixtures = resolve(desktop, '../tests/fixtures');
const bin = join(desktop, 'src-tauri/target/debug/raffronto');
const out = process.env.OUT ?? '/tmp/raffronto-desktop';
const port = 47000 + Math.floor(Math.random() * 900);
const withPrint = process.argv.includes('--print');
mkdirSync(out, { recursive: true });
if (!existsSync(bin)) { console.error('Build first: cd src-tauri && cargo build'); process.exit(1); }

const downloadedBefore = existsSync(join(homedir(), 'Downloads', 'regulation-v2 - con revisioni.docx'));
const app = spawn(bin, [], { env: { ...process.env, RAFFRONTO_DEBUG_PORT: String(port) } });
const pageErrors = [], waiting = new Map();
let buffer = '';
app.stderr.on('data', chunk => {
  buffer += chunk;
  let i;
  while ((i = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, i); buffer = buffer.slice(i + 1);
    const m = /^\[page log\] __R (\d+) (.*)$/.exec(line);
    if (m) { waiting.get(+m[1])?.(JSON.parse(m[2])); continue; }
    if (/^\[page error\]/.test(line)) pageErrors.push(line);
    if (process.env.VERBOSE || /^\[page (error|warn)\]/.test(line)) console.log('   ' + line);
  }
});

let seq = 0;
function page(body, timeout = 60e3) {
  const id = ++seq;
  const js = `//raffronto-debug\n(async () => { let r; try { r = await (async () => { ${body} })(); } catch (e) { r = { error: String(e) + (e && e.stack ? " @ " + e.stack : "") }; }
    console.log('__R ${id} ' + JSON.stringify(r === undefined ? null : r)); })();`;
  return new Promise((ok, fail) => {
    const t = setTimeout(() => { waiting.delete(id); fail(new Error('timeout: ' + body.slice(0, 80))); }, timeout);
    waiting.set(id, r => { clearTimeout(t); waiting.delete(id); ok(r); });
    const s = net.connect(port, '127.0.0.1', () => s.end(js));
    s.on('error', e => { clearTimeout(t); fail(e); });
  });
}
const sleep = ms => new Promise(r => setTimeout(r, ms));
const results = [];
function check(name, ok, detail = '') { results.push(ok); console.log(`${ok ? 'OK  ' : 'FAIL'} ${name}${detail ? ': ' + detail : ''}`); }

// helpers defined once in the page
const HELPERS = `
  window.__t = {
    sleep: ms => new Promise(r => setTimeout(r, ms)),
    async until(fn, ms = 30000) { const end = Date.now() + ms; while (Date.now() < end) { const v = fn(); if (v) return v; await __t.sleep(100); } const S = window.__raffronto; throw new Error('condition not met: ' + fn + ' | ' + JSON.stringify({ vis: document.visibilityState, landing: !document.querySelector('#landing').hidden, ws: !document.querySelector('#ws').hidden, dlg: !document.querySelector('#dlg').hidden, result: !!S.result, sides: S.sides.map(x => x?.file.name), busy: document.querySelector('.busy, #busy')?.outerHTML.slice(0, 120) })); },
    file(name, b64, type) { return new File([Uint8Array.from(atob(b64), c => c.charCodeAt(0))], name, { type, lastModified: Date.now() }); },
    drop(files) { const dt = new DataTransfer(); files.forEach(f => dt.items.add(f)); document.dispatchEvent(new DragEvent('drop', { dataTransfer: dt, bubbles: true, cancelable: true })); },
    ready: () => !document.querySelector('#ws').hidden && window.__raffronto.result && !document.body.classList.contains('busy') && !document.querySelector('.busy:not([hidden])'),
  };
  return true;`;

const b64 = f => readFileSync(join(fixtures, f)).toString('base64');
const type = f => f.endsWith('.pdf') ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
async function compare(a, b) {
  await page(`if (!document.querySelector('#ws').hidden) document.querySelector('#newBtn').click();
    await __t.until(() => !document.querySelector('#landing').hidden && document.querySelector('#ws').hidden); await __t.sleep(300); return true;`);
  return page(`__t.drop([__t.file(${JSON.stringify(a)}, '${b64(a)}', '${type(a)}'), __t.file(${JSON.stringify(b)}, '${b64(b)}', '${type(b)}')]);
    await __t.until(__t.ready);
    await __t.sleep(500);
    const S = window.__raffronto;
    return { hunks: S.hunks.length, sides: S.sides.map(s => s.file.name), pages: [...document.querySelectorAll('.pane')].map(p => p.querySelectorAll('.page, canvas').length) };`);
}

try {
  for (let i = 0; i < 100; i++) { try { await page('return 1', 500); break; } catch { await sleep(200); } }
  await page(HELPERS);

  const env = await page(`return { href: location.href, secure: isSecureContext, sans: document.fonts.check('16px "Instrument Sans"'), serif: document.fonts.check('16px "Instrument Serif"'), share: !document.querySelector('#shareBtn') || document.querySelector('#shareBtn').hidden };`);
  check('pagina caricata da tauri://', env.href.startsWith('tauri://') || env.href.startsWith('http://tauri.localhost'), env.href);
  check('font inclusi', env.sans && env.serif);

  const docx = await compare('regulation-v1.docx', 'regulation-v2.docx');
  check('docx: regolamento v1 vs v2, 55 differenze come in Chromium', docx.hunks === 55, JSON.stringify(docx));
  check('condivisione nascosta', await page(`return document.querySelector('#shareBtn')?.hidden ?? true`));

  // Word with revisions: the page creates a blob and clicks a download link
  const word = await page(`
    const clicks = [];
    const orig = HTMLAnchorElement.prototype.click;
    HTMLAnchorElement.prototype.click = function () { clicks.push({ download: this.download, href: this.href.slice(0, 12) }); return orig.call(this); };
    document.querySelector('#printBtn').click(); await __t.sleep(200);
    document.querySelector('[data-export="docx"]').click();
    await __t.until(() => clicks.length, 20000);
    HTMLAnchorElement.prototype.click = orig;
    const S = window.__raffronto, txt = S.hunks.filter(h => !h.vis);
    return { ...clicks[0], ins: txt.reduce((n, h) => n + h.b1 - h.b0, 0), del: txt.reduce((n, h) => n + h.a1 - h.a0, 0),
      insHunks: txt.filter(h => h.b1 > h.b0).length, delHunks: txt.filter(h => h.a1 > h.a0).length, texts: [null, null] };`);
  check('Word con revisioni: download avviato', word?.download === 'regulation-v2 - con revisioni.docx', word?.download);
  // the app saves downloads straight into ~/Downloads; the file is moved to OUT and checked like in tests/e2e.sh
  const saved = join(homedir(), 'Downloads', word.download);
  for (let i = 0; i < 50 && !existsSync(saved); i++) await sleep(200);
  if (!downloadedBefore && existsSync(saved)) {
    renameSync(saved, join(out, 'regulation.docx'));
    writeFileSync(join(out, 'regulation.json'), JSON.stringify(JSON.stringify(word))); // same double encoding as tests/e2e.sh
    const r = spawnSync('uv', ['run', '-q', resolve(fixtures, '../check_tracked.py'), join(out, 'regulation.docx'), '--browser', join(out, 'regulation.json'),
      '--left', join(fixtures, 'regulation-v1.docx'), '--right', join(fixtures, 'regulation-v2.docx')], { encoding: 'utf8' });
    check('Word con revisioni: file salvato in Download e valido (tests/check_tracked.py)', r.status === 0, (r.stdout + r.stderr).trim().slice(0, 300));
  } else check('Word con revisioni: file salvato in Download', false, downloadedBefore ? 'esisteva già, non lo tocco: ' + saved : 'non trovato: ' + saved);

  const pdf = await compare('agreement-v1.pdf', 'agreement-v2.pdf');
  check('pdf: contratto v1 vs v2, 2 differenze', pdf.hunks === 2, JSON.stringify(pdf));
  const net_ = await page(`return performance.getEntriesByType('resource').map(r => r.name).filter(u => !/^(tauri|ipc|blob|data):|^http:\\/\\/(tauri|ipc)\\.localhost/.test(u));`);
  check('nessuna risorsa dalla rete (pdf.js e font locali)', net_.length === 0, net_.join(', '));

  if (withPrint) {
    // print: beforeprint must arrive (it draws the PDF pages), then the macOS print panel opens;
    // whoever runs the check saves the PDF (PDF > Save as PDF) or cancels, and afterprint restores the page
    const p = await page(`
      window.__printLog = [];
      addEventListener('beforeprint', () => __printLog.push('beforeprint:' + !!document.querySelector('#printRoot')));
      addEventListener('afterprint', () => __printLog.push('afterprint'));
      window.__title0 = document.title;
      document.querySelector('#printBtn').click(); await __t.sleep(200);
      document.querySelector('[data-layout="both"]').click();
      await __t.until(() => __printLog.length, 30000);
      return { log: __printLog, title: document.title, sheets: document.querySelectorAll('#printRoot .sheet').length };`);
    check('stampa: beforeprint con i fogli pronti', p.log.includes('beforeprint:true'), JSON.stringify(p));
    console.log(`   pannello di stampa aperto (app pid ${app.pid}): salva il PDF o annulla`);
    const after = await page(`await __t.until(() => __printLog.includes('afterprint'), 600000); await __t.sleep(300);
      return { log: __printLog, title: document.title === __title0, root: !!document.querySelector('#printRoot') };`, 610e3);
    check('stampa: afterprint, pagina ripristinata', after.title && !after.root, JSON.stringify(after));
  }

  if (pageErrors.length) check('nessun errore nella pagina', false, pageErrors.length + ' errori');
  else check('nessun errore nella pagina', true);
} catch (e) {
  check('esecuzione', false, String(e));
} finally {
  app.kill();
}
console.log(results.every(Boolean) ? '\nTutto OK' : `\n${results.filter(r => !r).length} controlli falliti`);
process.exit(results.every(Boolean) ? 0 : 1);
