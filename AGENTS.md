# Raffronto (diff tracker)

Diff tracker di documenti .docx e .pdf in una sola pagina HTML, tutto client-side. Sorgente `src/index.html` (testi in inglese, traduzioni in `src/strings.it.json`, pagine per lingua e professione in `src/pages.mjs`); `node scripts/build.mjs` genera `site/`, da non modificare a mano.

- Documentazione di progetto in `docs/` (vedi `docs/README.md`: funzioni, architettura, verifiche, limiti).
- Test end-to-end: `tests/e2e.sh` (browser reale via playwright-cli solo su documenti sintetici in `tests/fixtures`, rigenerabili con `uv run tests/fixtures/make.py`; niente file personali).
- In locale Herd serve `site/`: http://diff-tracker.test (`tests/e2e.sh` rigenera il sito da solo).
- Online: Cloudflare Workers, cartella `cloudflare/` (deploy: `cd cloudflare && npm run deploy`; API dei link condivisi in `cloudflare/src/index.ts`, archivio su R2), su https://raffronto.app (anche https://raffronto.16bit.workers.dev). Il vecchio https://tools.16bit.cloud/raffronto/ (`dep deploy`, `share.php`) resta acceso per i link già creati: vedi docs. Test sul sito online: `URL=https://raffronto.app/ tests/e2e.sh` (la condivisione si prova sempre in locale).
- App installabile (PWA): `src/manifest.webmanifest`, `src/sw.js`, `src/icons/`; test in `tests/pwa.sh` (chiamato da `e2e.sh`).
- Lingue e pagine per professione: test in `tests/pages.sh` e `tests/english.sh`; vedi docs.
- Marketing: anteprima dei link (`src/social.png`, `src/social-en.png`, sorgente in `brand/social/`), `robots.txt`, `sitemap.xml`, statistiche Umami (mai la parte dopo `#`); test in `tests/marketing.sh` (chiamato da `e2e.sh`); vedi docs.
- App desktop (Tauri 2) in `desktop/`: usa la home italiana generata (`site/index.html`) con pdf.js e font inclusi; vedi `desktop/README.md`.
- Marchio in `brand/` (direzione scelta: `brand/logo/01-fogli-nastro/`, indicazioni in `brand/README.md`).
- Commit della cartella `docs/`: da chiedere (la cartella non è un repository git al 9/10/2026).
