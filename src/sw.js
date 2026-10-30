// Offline copy of the app. The page is always asked to the network first, so a new deploy shows up at once;
// pdf.js (pinned version) and the fonts come from the cache. The share API is never cached.
const CACHE = 'raffronto-v4';
const PDFJS = 'https://cdn.jsdelivr.net/npm/pdfjs-dist@4.10.38/build/';
const PRECACHE = ['/', '/en/', '/manifest.webmanifest', '/en/manifest.webmanifest', '/icons/icon.svg', '/icons/icon-192.png', '/icons/icon-512.png', PDFJS + 'pdf.min.mjs', PDFJS + 'pdf.worker.min.mjs'];

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
  if (req.method !== 'GET' || url.pathname.startsWith('/api/')) return;
  if (req.mode === 'navigate') {
    // every page is the whole app in one file (a shared comparison lives in the fragment): offline, a page
    // never opened before falls back to the home page of its language
    const home = url.pathname.startsWith('/en/') ? '/en/' : '/';
    e.respondWith(fetch(req).then(res => {
      if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(url.pathname, copy)); }
      return res;
    }).catch(async () => (await caches.match(url.pathname)) || caches.match(home)));
    return;
  }
  const own = url.origin === location.origin;
  if (!own && !url.href.startsWith(PDFJS) && !/^fonts\.(googleapis|gstatic)\.com$/.test(url.hostname)) return;
  e.respondWith(caches.match(req).then(hit => {
    const net = fetch(req).then(res => {
      if (res.ok || res.type === 'opaque') { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
      return res;
    });
    // pinned pdf.js never changes; own files and fonts are refreshed in the background
    if (hit && !own && url.href.startsWith(PDFJS)) return hit;
    if (hit) { e.waitUntil(net.catch(() => {})); return hit; }
    return net;
  }));
});
