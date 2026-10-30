// Builds desktop/dist from the web app: builds the site (../scripts/build.mjs), takes its Italian home page
// (../site/index.html) and adapts it to run offline inside the app.
// Every patch must match exactly once, so a change to index.html that breaks one stops the build
// instead of shipping an app that silently goes back to the network.
import { readFileSync, writeFileSync, mkdirSync, rmSync, copyFileSync, existsSync, statSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const desktop = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const root = resolve(desktop, '..');
const dist = join(desktop, 'dist');
const modules = join(desktop, 'node_modules');

if (!existsSync(join(modules, 'pdfjs-dist'))) {
  console.error('Missing node_modules: run "npm install" in desktop/ first.');
  process.exit(1);
}

execFileSync(process.execPath, [join(root, 'scripts/build.mjs')], { stdio: 'inherit' });
const site = join(root, 'site');
let html = readFileSync(join(site, 'index.html'), 'utf8');

function patch(label, pattern, replacement) {
  const hits = html.match(new RegExp(pattern.source, pattern.flags.includes('g') ? pattern.flags : pattern.flags + 'g'));
  if (!hits || hits.length !== 1) {
    console.error(`prepare-web: patch "${label}" matched ${hits ? hits.length : 0} times instead of once; update scripts/prepare-web.mjs.`);
    process.exit(1);
  }
  html = html.replace(pattern, replacement);
}

rmSync(dist, { recursive: true, force: true });
mkdirSync(join(dist, 'vendor/pdfjs'), { recursive: true });
mkdirSync(join(dist, 'fonts'), { recursive: true });

// 1. pdf.js from the npm package instead of jsDelivr; the version must be the one index.html asks for
const pdfjsVersion = JSON.parse(readFileSync(join(modules, 'pdfjs-dist/package.json'), 'utf8')).version;
const wanted = /https:\/\/cdn\.jsdelivr\.net\/npm\/pdfjs-dist@([\d.]+)\/build\//.exec(html)?.[1];
if (wanted !== pdfjsVersion) {
  console.error(`prepare-web: index.html uses pdf.js ${wanted ?? '(not found)'}, desktop/package.json has ${pdfjsVersion}. Align "pdfjs-dist" and run npm install.`);
  process.exit(1);
}
html = html.replaceAll(`https://cdn.jsdelivr.net/npm/pdfjs-dist@${pdfjsVersion}/build/`, './vendor/pdfjs/');
for (const f of ['pdf.min.mjs', 'pdf.worker.min.mjs']) copyFileSync(join(modules, 'pdfjs-dist/build', f), join(dist, 'vendor/pdfjs', f));
copyFileSync(join(modules, 'pdfjs-dist/LICENSE'), join(dist, 'vendor/pdfjs/LICENSE'));

// 2. Google Fonts replaced by the same families from Fontsource, bundled
patch('google fonts', /<link rel="preconnect" href="https:\/\/fonts\.googleapis\.com">\n<link rel="preconnect" href="https:\/\/fonts\.gstatic\.com" crossorigin>\n<link href="https:\/\/fonts\.googleapis\.com\/css2\?[^"]*" rel="stylesheet">/,
  '<link href="fonts/fonts.css" rel="stylesheet">');
let css = '';
for (const file of ['@fontsource-variable/instrument-sans/wght.css', '@fontsource/instrument-serif/400.css', '@fontsource/instrument-serif/400-italic.css']) {
  const dir = dirname(join(modules, file));
  css += readFileSync(join(modules, file), 'utf8').replace(/url\(\.\/files\/([^)]+)\)/g, (_, name) => {
    copyFileSync(join(dir, 'files', name), join(dist, 'fonts', name));
    return `url(${name})`;
  }) + '\n';
}
writeFileSync(join(dist, 'fonts/fonts.css'), css.replaceAll("'Instrument Sans Variable'", "'Instrument Sans'"));

// 3. Share by link: hidden. share.php is not in the app, and the online one does not accept requests
// from the app (other origin, no CORS); the receiver would need the web page anyway.
patch('share button', /const canShare = \(\) => /, 'const canShare = () => false && ');
patch('privacy note', /I documenti restano sul tuo computer, a meno che tu non scelga di condividerli\./, 'I documenti restano sul tuo computer.');

// 4. Visit statistics, the desktop app download link and the other site links are for the website only; the 16bit credit stays as plain text, since a link would
// take the app window away from the comparison
patch('statistics', /<!-- visit statistics[^\n]*\n<script defer src="https:\/\/stats\.16bit\.cloud\/s\.js"[^\n]*\n/, '');
patch('language hint', /<div class="lang-hint"[^]*?<\/span><\/div>\n/, '');
patch('download button', /  <a class="btn get-app site-only" id="getApp"[^\n]*\n/, '');
patch('pages for each profession', /<nav class="for"[^]*?<\/nav>/, '');
patch('language switch', /<a href="\/en" hreflang="en" lang="en">English<\/a> /, '');
patch('desktop app, privacy and terms', /<a href="\/scarica">App per computer<\/a> <a href="\/privacy">Privacy<\/a> <a href="\/termini">Termini<\/a> /, '');
patch('16bit credit', /<a class="by" href="https:\/\/16bit\.it\/">([^]*?)<\/a>/, '<span class="by">$1</span>');

// 4b. App look: a quiet start screen (short title and hint instead of the marketing hero, no site sections,
// footer reduced to the 16bit credit) and native-feeling chrome. Everything hangs on the "app" class on
// <html>, so the page markup stays the one of the site; on macOS the title bar is drawn over the top bar
// (titleBarStyle "Overlay" in tauri.conf.json), which leaves room for the window buttons and drags the window.
patch('hero copy', /<h1>[^]*?<\/h1>\s*<p class="lede">[^]*?<\/p>/,
  '<h1 class="app-title">Confronta due documenti</h1>\n    <p class="app-hint">Word o PDF: l’originale a sinistra, la nuova versione a destra.</p>');
const APP_STYLE = `
.app body { -webkit-user-select: none; user-select: none; cursor: default; }
.app .scroller, .app .list, .app input, .app textarea { -webkit-user-select: text; user-select: text; }
.app button, .app label, .app .chip, .app .chg, .app .zoom output { cursor: default; }
.app img, .app svg { -webkit-user-drag: none; }
.app, .app body, .app .landing { overscroll-behavior: none; }
.app.mac .topbar { padding-left: 90px; }
.app.mac.fullscreen .topbar { padding-left: 18px; }
.app .site-only, .app .uses, .app .credit > :not(.end), .app .credit .end > :not(.by) { display: none !important; }
.app .landing { grid-template-rows: 1fr auto; align-content: stretch; padding: 32px 32px 0; }
.app .hero { align-self: center; max-width: 880px; }
.app .app-title { font-family: var(--display); font-weight: 400; font-size: 34px; line-height: 1.15; letter-spacing: -.01em; margin: 0 0 6px; }
.app .app-hint { margin: 0 0 24px; color: var(--muted); font-size: 14.5px; line-height: 1.5; }
.app .drop { min-height: 260px; }
.app .credit { max-width: none; margin: 0; padding: 20px 0 18px; border: 0; justify-content: center; font-size: 12px; color: var(--faint); }
.app .credit .by img { height: 14px; }
`;
// runs in <head>: the classes are there before the first paint; the drag region is the top bar, minus
// the controls in it that are not buttons (Tauri already leaves buttons, links and menu items alone)
const APP_SCRIPT = `
(() => {
  const root = document.documentElement;
  root.classList.add('app');
  addEventListener('DOMContentLoaded', () => {
    document.querySelector('.topbar')?.setAttribute('data-tauri-drag-region', 'deep');
    for (const el of document.querySelectorAll('#zoomVal, #printMenu')) el.setAttribute('data-tauri-drag-region', 'false');
  });
  if (!/Mac/.test(navigator.platform)) return;
  root.classList.add('mac');
  // in full screen the window buttons are gone, and so is the room left for them
  const invoke = window.__TAURI_INTERNALS__?.invoke;
  const check = () => invoke?.('plugin:window|is_fullscreen', { label: 'main' }).then(f => root.classList.toggle('fullscreen', f), () => {});
  addEventListener('resize', check);
  check();
})();
`;
patch('app look', /<\/head>/, `<style id="app-style">${APP_STYLE}</style>\n<script>${APP_SCRIPT}</script>\n</head>`);

// 5. Local files the page may reference (icons, manifest, service worker), copied when they exist; paths are
// absolute, and the app serves dist/ as its root
for (const [, ref] of html.matchAll(/(?:href|src)="(?!https?:|data:|#|\/\/)([^"?#]+)"/g)) {
  const from = join(site, ref);
  if (existsSync(join(dist, ref)) || !existsSync(from) || statSync(from).isDirectory()) continue;
  mkdirSync(dirname(join(dist, ref)), { recursive: true });
  copyFileSync(from, join(dist, ref));
}

writeFileSync(join(dist, 'index.html'), html);

// whatever still points to the network, so it gets noticed (XML namespaces are just names)
const ignored = /^https?:\/\/(schemas\.openxmlformats\.org|schemas\.microsoft\.com|purl\.org|www\.w3\.org|ns\.adobe\.com|tools\.16bit\.cloud|schema\.org|raffronto\.app|16bit\.it)/;
const left = [...new Set(html.match(/https?:\/\/[^\s"'`)<>]+/g) ?? [])].filter(u => !ignored.test(u));
if (left.length) console.warn('prepare-web: network URLs still in index.html:\n  ' + left.join('\n  '));
console.log(`prepare-web: dist ready (pdf.js ${pdfjsVersion}, fonts bundled, share hidden).`);
