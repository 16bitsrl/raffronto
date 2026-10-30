// Offline copy of the app. The page is always asked to the network first, so a new deploy shows up at once;
// pdf.js (pinned version) and the fonts, all served by the site itself, come from the cache. The share API and
// the app downloads are never cached.
const CACHE = 'raffronto-v6';
const PDFJS = '/vendor/pdfjs/4.10.38/';
const PRECACHE = ['/', '/en', '/manifest.webmanifest', '/en/manifest.webmanifest', '/icons/icon.svg', '/icons/icon-192.png', '/icons/icon-512.png', PDFJS + 'pdf.min.mjs', PDFJS + 'pdf.worker.min.mjs',
  '/fonts/fonts.css', '/fonts/instrument-sans-latin-wght-normal.woff2', '/fonts/instrument-serif-latin-400-normal.woff2', '/fonts/instrument-serif-latin-400-italic.woff2'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const req = e.request, url = new URL(req.url);
  if (req.method !== 'GET' || url.pathname.startsWith('/api/') || url.pathname.startsWith('/download/')) return;
  if (req.mode === 'navigate') {
    // every page is the whole app in one file (a shared comparison lives in the fragment): offline, a page
    // never opened before falls back to the home page of its language. Page addresses have no trailing slash
    // (/en, /avvocati): an old address with it shares the copy of the one without.
    const path = url.pathname.length > 1 ? url.pathname.replace(/\/+$/, '') : '/';
    const home = path === '/en' || path.startsWith('/en/') ? '/en' : '/';
    e.respondWith(fetch(req).then(res => {
      if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(path, copy)); }
      return res;
    }).catch(async () => (await caches.match(path)) || caches.match(home)));
    return;
  }
  if (url.origin !== location.origin) return;
  e.respondWith(caches.match(req).then(hit => {
    const net = fetch(req).then(res => {
      if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
      return res;
    });
    // pinned pdf.js never changes; the other files are refreshed in the background
    if (hit && url.pathname.startsWith(PDFJS)) return hit;
    if (hit) { e.waitUntil(net.catch(() => {})); return hit; }
    return net;
  }));
});
