// Desktop app download page, site only. scripts/build.mjs puts it in src/legal.html (same header and footer as the
// privacy policy) and writes site/<path>/index.html; `link` is the label in the footers. Files are the ones of the latest
// GitHub release, under the fixed names uploaded by .github/workflows/desktop.yml (publish job), but the links point
// to /download/<name> on the site: the Worker (cloudflare/src/index.ts) fetches them from GitHub, so GitHub never
// receives the visitor's address. Only "what's new" links to the release page on GitHub.
// The script below picks the visitor's system and shows its block (.pick[data-for]) and note (.first-run [data-for]);
// without it, or on phones, tablets and unknown systems, the list of all versions does the job.

const RELEASES = 'https://github.com/16bitsrl/raffronto/releases';
const file = name => `/download/Raffronto-${name}`;

// every file, by system: key, file name, label per language
const files = {
  mac: [
    ['mac-arm64', 'mac-arm64.dmg', { it: 'Mac con chip Apple (M1 e successivi)', en: 'Mac with Apple chip (M1 and later)' }],
    ['mac-x64', 'mac-x64.dmg', { it: 'Mac con processore Intel', en: 'Mac with Intel processor' }],
  ],
  windows: [
    ['windows-x64', 'windows-x64-setup.exe', { it: 'Windows 10 e 11, 64 bit', en: 'Windows 10 and 11, 64-bit' }],
    ['windows-x64-msi', 'windows-x64.msi', { it: 'Windows 64 bit, pacchetto .msi per le aziende', en: 'Windows 64-bit, .msi package for companies' }],
    ['windows-arm64', 'windows-arm64-setup.exe', { it: 'Windows su processore ARM', en: 'Windows on ARM' }],
  ],
  linux: [
    ['linux-x64', 'linux-x64.AppImage', { it: 'Linux 64 bit, AppImage', en: 'Linux 64-bit, AppImage' }],
    ['linux-x64-deb', 'linux-x64.deb', { it: 'Linux 64 bit, .deb per Debian e Ubuntu', en: 'Linux 64-bit, .deb for Debian and Ubuntu' }],
    ['linux-arm64', 'linux-arm64.AppImage', { it: 'Linux ARM, AppImage', en: 'Linux ARM, AppImage' }],
    ['linux-arm64-deb', 'linux-arm64.deb', { it: 'Linux ARM, .deb per Debian e Ubuntu', en: 'Linux ARM, .deb for Debian and Ubuntu' }],
  ],
};
const byKey = Object.fromEntries(Object.values(files).flat().map(([k, f, l]) => [k, { f, l }]));
const systems = { mac: 'macOS', windows: 'Windows', linux: 'Linux' };

// the big button for each detected system, and the other files of that system right under it
const picks = [
  ['mac-arm64', 'mac', ['mac-x64']],
  ['mac-x64', 'mac', ['mac-arm64']],
  ['windows-x64', 'windows', ['windows-x64-msi', 'windows-arm64']],
  ['windows-arm64', 'windows', ['windows-x64']],
  ['linux-x64', 'linux', ['linux-x64-deb', 'linux-arm64']],
  ['linux-arm64', 'linux', ['linux-arm64-deb', 'linux-x64']],
];

const ui = {
  it: {
    path: '/scarica', link: 'App per computer',
    title: 'Raffronto per il tuo computer', htmlTitle: 'Scarica Raffronto per Mac, Windows e Linux',
    description: 'Scarica Raffronto per Mac, Windows e Linux: confronta due documenti Word o PDF in una finestra sua, anche senza connessione. Gratuito, i documenti restano sul tuo computer.',
    lede: 'La stessa app del sito, in una finestra sua: si apre senza browser e confronta anche senza connessione. Gratuita.',
    button: { mac: 'Scarica per Mac', windows: 'Scarica per Windows', linux: 'Scarica per Linux' },
    other: 'Oppure',
    inBrowser: 'Su telefono e tablet Raffronto funziona nel browser, senza installare nulla: <a href="/">apri Raffronto</a>.',
    unknown: 'Scegli il file per il tuo sistema qui sotto. Raffronto funziona anche nel browser, senza installare nulla: <a href="/">apri Raffronto</a>.',
    firstRun: 'Al primo avvio',
    notes: {
      mac: 'L’app non è ancora verificata da Apple, quindi la prima volta macOS chiede conferma. Apri il file scaricato, trascina Raffronto in Applicazioni, poi fai clic destro su Raffronto e scegli <b>Apri</b>. Se macOS non lo permette: <b>Impostazioni di Sistema &gt; Privacy e sicurezza</b>, in fondo <b>Apri comunque</b>.',
      windows: 'L’app non è ancora firmata, quindi Windows può mostrare l’avviso “Windows ha protetto il PC”: scegli <b>Ulteriori informazioni</b>, poi <b>Esegui comunque</b>.',
      linux: 'AppImage: nelle proprietà del file consenti di eseguirlo come programma, poi aprilo con un doppio clic. Il pacchetto .deb si installa come le altre app.',
    },
    all: 'Tutte le versioni',
    notesLink: 'Novità e versioni precedenti',
  },
  en: {
    path: '/en/download', link: 'Desktop app',
    title: 'Raffronto for your computer', htmlTitle: 'Download Raffronto for Mac, Windows and Linux',
    description: 'Download Raffronto for Mac, Windows and Linux: compare two Word or PDF documents in a window of its own, even offline. Free, your documents stay on your computer.',
    lede: 'The same app as the website, in a window of its own: it opens without a browser and compares even offline. Free.',
    button: { mac: 'Download for Mac', windows: 'Download for Windows', linux: 'Download for Linux' },
    other: 'Or',
    inBrowser: 'On phones and tablets Raffronto works in the browser, with nothing to install: <a href="/en">open Raffronto</a>.',
    unknown: 'Pick the file for your system below. Raffronto also works in the browser, with nothing to install: <a href="/en">open Raffronto</a>.',
    firstRun: 'The first time you open it',
    notes: {
      mac: 'The app is not yet verified by Apple, so the first time macOS asks you to confirm. Open the downloaded file, drag Raffronto to Applications, then right-click Raffronto and choose <b>Open</b>. If macOS does not allow it: <b>System Settings &gt; Privacy &amp; Security</b>, then <b>Open Anyway</b> at the bottom.',
      windows: 'The app is not signed yet, so Windows may show “Windows protected your PC”: choose <b>More info</b>, then <b>Run anyway</b>.',
      linux: 'AppImage: in the file’s properties allow it to run as a program, then double-click it. The .deb package installs like any other app.',
    },
    all: 'All versions',
    notesLink: 'What’s new and earlier versions',
  },
};

const ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4v11M7 10l5 5 5-5M5 20h14"/></svg>';

function body(lang) {
  const t = ui[lang];
  const pickBlocks = picks.map(([key, os, more]) => `
<div class="pick" data-for="${key}" hidden>
  <a class="primary" href="${file(byKey[key].f)}">${ICON}<span><b>${t.button[os]}</b><small>${byKey[key].l[lang]}</small></span></a>
  <p class="more">${t.other}: ${more.map(k => `<a href="${file(byKey[k].f)}">${byKey[k].l[lang]}</a>`).join(' · ')}</p>
</div>`).join('');
  return `
<section class="get" aria-live="polite">${pickBlocks}
<p class="in-browser" data-for="mobile" hidden>${t.inBrowser}</p>
<p class="in-browser" data-for="unknown" hidden>${t.unknown}</p>
</section>
<section class="first-run">
<h2>${t.firstRun}</h2>
${Object.keys(systems).map(os => `<p data-for="${os}"><b>${systems[os]}.</b> ${t.notes[os]}</p>`).join('\n')}
</section>
<section class="all">
<h2>${t.all}</h2>
${Object.entries(files).map(([os, list]) => `<h3>${systems[os]}</h3>
<ul>${list.map(([, f, l]) => `<li><a href="${file(f)}">${l[lang]}</a> <span>Raffronto-${f}</span></li>`).join('')}</ul>`).join('\n')}
<p class="releases"><a href="${RELEASES}/latest">${t.notesLink}</a></p>
</section>
<script>${SCRIPT}</script>`;
}

// which file fits this computer: the browser's own report where there is one (Chromium), otherwise the user
// agent; a Mac without it (Safari, Firefox) tells Apple chips by the graphics name, and Safari hides even that,
// so it defaults to Apple chips, with the Intel file right under the button
const SCRIPT = `
(async () => {
  const ua = navigator.userAgent, uad = navigator.userAgentData;
  let platform = uad?.platform || '', arch = '';
  try { if (uad?.getHighEntropyValues) ({ platform = platform, architecture: arch = '' } = await uad.getHighEntropyValues(['architecture', 'platform'])); } catch {}
  const mobile = uad?.mobile || /iPhone|iPad|iPod|Android|Mobi/i.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  const os = mobile ? 'mobile'
    : /^mac/i.test(platform) || (!platform && /Macintosh|Mac OS X/.test(ua)) ? 'mac'
    : /^win/i.test(platform) || (!platform && /Windows/.test(ua)) ? 'windows'
    : /^linux/i.test(platform) || (!platform && /Linux/.test(ua) && !/CrOS/.test(ua)) ? 'linux' : 'unknown';
  let key = null;
  if (os === 'mac') {
    let gpu = '';
    if (!arch) try { const gl = document.createElement('canvas').getContext('webgl'); const ext = gl?.getExtension('WEBGL_debug_renderer_info'); gpu = ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : ''; } catch {}
    key = arch === 'x86' || (!arch && /Intel|AMD|Radeon|NVIDIA/i.test(gpu)) ? 'mac-x64' : 'mac-arm64';
  } else if (os === 'windows') key = arch === 'arm' || /ARM64/i.test(ua) ? 'windows-arm64' : 'windows-x64';
  else if (os === 'linux') key = arch === 'arm' || /aarch64|arm64|armv8/i.test(ua) ? 'linux-arm64' : 'linux-x64';
  const show = sel => { for (const e of document.querySelectorAll(sel)) e.hidden = false; };
  if (key) {
    show('.pick[data-for="' + key + '"]');
    for (const p of document.querySelectorAll('.first-run [data-for]')) p.hidden = p.dataset.for !== os;
  } else {
    show('.in-browser[data-for="' + os + '"]');
    // nothing to install on a phone: straight to the list
    if (os === 'mobile') document.querySelector('.first-run').hidden = true;
  }
  document.documentElement.dataset.os = os;
})();
`;

const HEAD = `<style>
.get { margin: 0 0 40px; }
.pick { display: grid; justify-items: start; gap: 12px; }
.pick[hidden], .in-browser[hidden], .first-run[hidden], .first-run [hidden] { display: none; }
.primary { display: inline-flex; align-items: center; gap: 14px; padding: 14px 26px 14px 20px; border-radius: 14px; background: var(--brand); color: var(--chrome); text-decoration: none; box-shadow: 0 1px 2px rgb(0 0 0 / .12), 0 6px 18px -6px color-mix(in srgb, var(--brand) 60%, transparent); transition: transform .15s ease, box-shadow .15s ease; }
.primary:hover { transform: translateY(-1px); box-shadow: 0 2px 4px rgb(0 0 0 / .14), 0 10px 24px -8px color-mix(in srgb, var(--brand) 70%, transparent); }
.primary:active { transform: translateY(0); }
.primary svg { width: 24px; height: 24px; flex: none; }
.primary span { display: grid; gap: 1px; }
.primary b { font-size: 18px; font-weight: 600; line-height: 1.3; }
.primary small { font-size: 13px; opacity: .8; line-height: 1.35; }
.more { margin: 0; color: var(--muted); font-size: 14px; }
.in-browser { margin: 0; font-size: 15px; }
.first-run { margin: 0 0 8px; }
.first-run p { color: var(--ink); }
.all h3 { font-size: 13px; font-weight: 600; text-transform: uppercase; letter-spacing: .06em; color: var(--muted); margin: 22px 0 6px; }
.all ul { list-style: none; padding: 0; margin: 0; border-top: 1px solid var(--line); }
.all li { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: baseline; gap: 2px 16px; padding: 9px 0; margin: 0; border-bottom: 1px solid var(--line); }
.all li span { color: var(--muted); font-size: 13px; }
.releases { margin-top: 24px; }
@media (max-width: 520px) { .primary { width: 100%; } .all li { flex-direction: column; } }
</style>`;

export const download = {
  id: 'download',
  ...Object.fromEntries(Object.keys(ui).map(lang => [lang, {
    path: ui[lang].path, link: ui[lang].link, title: ui[lang].title, htmlTitle: ui[lang].htmlTitle, description: ui[lang].description,
    lede: ui[lang].lede, head: HEAD, body: body(lang),
  }])),
};
