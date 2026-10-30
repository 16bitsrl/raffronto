// Builds the site in site/ from src/: one page per language and per entry of src/pages.mjs, plus manifests,
// sitemap, service worker, icons and preview images. Usage: node scripts/build.mjs
//
// src/index.html is written in English. Texts in the markup are {{English text}}, texts in the script are
// tx('English text'); src/strings.it.json translates them. A text without its Italian translation stops the
// build, so the Italian site never shows English by accident. {{@name}} are the slots filled per page.
import { readFileSync, writeFileSync, mkdirSync, rmSync, cpSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pages, languages } from '../src/pages.mjs';
import { legal, legalUi } from '../src/legal.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const src = join(root, 'src'), out = join(root, 'site');
const ORIGIN = 'https://raffronto.app';
const LANGS = ['it', 'en'];

const template = readFileSync(join(src, 'index.html'), 'utf8');
const dict = { it: JSON.parse(readFileSync(join(src, 'strings.it.json'), 'utf8')), en: {} };

// every translatable text of the template
const markupKeys = [...template.matchAll(/\{\{(?!@)(.+?)\}\}/gs)].map(m => m[1]);
const scriptKeys = [];
for (const m of template.matchAll(/\btx\(\s*(['"`])((?:\\.|(?!\1)[^\\])*)\1/g)) {
  if (m[1] === '`' && m[2].includes('${')) fail(`tx() with \${...} inside: use a {placeholder} instead: ${m[2]}`);
  scriptKeys.push(Function(`return ${m[1]}${m[2]}${m[1]}`)());
}
const missing = [...new Set([...markupKeys, ...scriptKeys])].filter(k => !(k in dict.it));
if (missing.length) fail('missing in src/strings.it.json:\n  ' + missing.join('\n  '));
const unused = Object.keys(dict.it).filter(k => !markupKeys.includes(k) && !scriptKeys.includes(k));
if (unused.length) console.warn('build: unused in src/strings.it.json:\n  ' + unused.join('\n  '));

function fail(msg) { console.error('build: ' + msg); process.exit(1); }
const attr = s => s.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;');
const url = path => ORIGIN + path;
const other = lang => LANGS.find(l => l !== lang);

function render(page, lang) {
  const p = page[lang], L = languages[lang], o = other(lang);
  const nav = pages.filter(x => x[lang].nav).map(x =>
    `<a href="${x[lang].path}"${x === page ? ' aria-current="page"' : ''}>${x[lang].nav}</a>`).join('');
  const sections = p.cards ? `<section class="uses">
    <h2>${p.h2}</h2>
    <div class="cards">${p.cards.map(([h, t]) => `
      <article><h3>${h}</h3><p>${t}</p></article>`).join('')}
    </div>
  </section>` : '';
  const jsonld = {
    '@context': 'https://schema.org', '@type': 'WebApplication', name: 'Raffronto', url: url(p.path),
    description: p.description, applicationCategory: 'BusinessApplication', operatingSystem: L.os,
    inLanguage: lang, isAccessibleForFree: true,
    offers: { '@type': 'Offer', price: '0', priceCurrency: 'EUR' },
    creator: { '@type': 'Organization', name: '16bit', url: 'https://16bit.it/' },
  };
  const slots = {
    lang, title: attr(p.title), description: attr(p.description), url: url(p.path), locale: L.locale,
    ogDescription: attr(p.cards ? p.description : L.slogan), image: url(L.image), imageAlt: attr(L.imageAlt),
    alternates: [...LANGS.map(l => `<link rel="alternate" hreflang="${l}" href="${url(page[l].path)}">`),
      `<link rel="alternate" hreflang="x-default" href="${url(page.en.path)}">`].join('\n'),
    jsonld: JSON.stringify(jsonld).replaceAll('<', '\\u003c'),
    manifest: lang === 'it' ? '/manifest.webmanifest' : `/${lang}/manifest.webmanifest`,
    hero: `<h1>${p.h1}</h1>\n    <p class="lede">${p.lede}</p>`,
    sections, professions: nav,
    langHint: `<a href="${page[o].path}" hreflang="${o}" lang="${o}">${languages[o].hint} →</a>`,
    langSwitch: `<a href="${page[o].path}" hreflang="${o}" lang="${o}">${languages[o].name}</a>`,
    legal: legal.map(d => `<a href="${d[lang].path}">${d[lang].link}</a>`).join(' '),
  };
  let html = template.replace(/\{\{@(\w+)\}\}/g, (m, k) => {
    if (!(k in slots)) fail('unknown slot ' + m);
    return slots[k];
  });
  html = html.replace(/\{\{(?!@)(.+?)\}\}/gs, (m, k) => {
    const v = dict[lang][k] ?? k;
    return v.replaceAll('"', '&quot;');
  });
  const strings = Object.fromEntries(scriptKeys.filter(k => k in dict[lang]).map(k => [k, dict[lang][k]]));
  const marker = 'const STRINGS = {/*STRINGS*/};';
  if (html.split(marker).length !== 2) fail('STRINGS marker not found exactly once');
  return html.replace(marker, () => `const STRINGS = ${JSON.stringify(strings).replaceAll('<', '\\u003c')};`);
}

rmSync(out, { recursive: true, force: true });
for (const page of pages) for (const lang of LANGS) {
  const dir = join(out, page[lang].path);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'index.html'), render(page, lang));
}

// privacy policy and terms of use (src/legal.mjs): plain pages in src/legal.html, not the app
const legalTemplate = readFileSync(join(src, 'legal.html'), 'utf8');
for (const doc of legal) for (const lang of LANGS) {
  const d = doc[lang], o = other(lang), ui = legalUi[lang];
  const slots = {
    lang, title: attr(`${d.title} · Raffronto`), description: attr(d.description), url: url(d.path),
    locale: languages[lang].locale,
    alternates: [...LANGS.map(l => `<link rel="alternate" hreflang="${l}" href="${url(doc[l].path)}">`),
      `<link rel="alternate" hreflang="x-default" href="${url(doc.en.path)}">`].join('\n'),
    home: pages[0][lang].path, homeLabel: attr(ui.home), themeTitle: attr(ui.theme), themeLabel: attr(ui.themeLabel),
    h1: d.title, updated: `${ui.updated} ${d.updated}`, body: d.body,
    footer: [`<a href="${pages[0][lang].path}">${ui.home}</a>`,
      ...legal.filter(x => x !== doc).map(x => `<a href="${x[lang].path}">${x[lang].link}</a>`),
      `<a class="end" href="${doc[o].path}" hreflang="${o}" lang="${o}">${languages[o].name}</a>`].join('\n'),
  };
  const html = legalTemplate.replace(/\{\{@(\w+)\}\}/g, (m, k) => {
    if (!(k in slots)) fail('unknown slot in legal.html ' + m);
    return slots[k];
  });
  mkdirSync(join(out, d.path), { recursive: true });
  writeFileSync(join(out, d.path, 'index.html'), html);
}

// one installable app per language, opening on its home page
const manifest = JSON.parse(readFileSync(join(src, 'manifest.webmanifest'), 'utf8'));
for (const lang of LANGS) {
  const home = pages[0][lang].path;
  const m = { ...manifest, lang, start_url: home, id: home, description: pages[0][lang].description };
  writeFileSync(join(out, home, 'manifest.webmanifest'), JSON.stringify(m, null, 2) + '\n');
}

writeFileSync(join(out, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
${[...pages, ...legal].flatMap(page => LANGS.map(lang => `  <url>
    <loc>${url(page[lang].path)}</loc>
${LANGS.map(l => `    <xhtml:link rel="alternate" hreflang="${l}" href="${url(page[l].path)}"/>`).join('\n')}
  </url>`)).join('\n')}
</urlset>
`);

for (const f of ['sw.js', 'robots.txt', 'icons', 'social.png', 'social-en.png', 'screens']) cpSync(join(src, f), join(out, f), { recursive: true });
console.log(`build: site/ ready (${(pages.length + legal.length) * LANGS.length} pages)`);
