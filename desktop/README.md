# Raffronto desktop

App desktop di Raffronto fatta con Tauri 2: una finestra che apre la stessa pagina della versione web (la home italiana generata da `../scripts/build.mjs`), con tutto il necessario incluso, quindi funziona anche senza rete. Nome "Raffronto", identificativo `cloud.16bit.raffronto`. Provata a mano su macOS; le build per macOS, Windows e Linux le fa GitHub Actions (vedi "Build su GitHub e download").

## Cosa serve

- Rust (stable) con `cargo`.
- Node.js e npm (per la CLI di Tauri qui, e per pdf.js e i font con `npm install` nella radice del repository).
- Su macOS gli strumenti a riga di comando di Xcode.

## Comandi

Tutti dalla cartella `desktop/`:

```sh
npm install              # una volta (e dopo ogni cambio di package.json)
npm run dev              # app di sviluppo con ricaricamento (npx tauri dev)
npm run build            # app e installatore: src-tauri/target/release/bundle/
npm run prepare-web      # solo la preparazione della pagina in dist/ (la fanno già dev e build)
npm run icons            # rigenera le icone dal marchio
node scripts/check-app.mjs [--print]   # prova l'app di sviluppo sui documenti di tests/fixtures
```

Risultato di `npm run build` su macOS (Apple Silicon): `src-tauri/target/release/bundle/macos/Raffronto.app` (circa 9 MB) e `bundle/dmg/Raffronto_0.1.0_aarch64.dmg` (circa 3,5 MB). Per un'app Intel: `npx tauri build --target x86_64-apple-darwin`; per una universale: `rustup target add x86_64-apple-darwin` e `npx tauri build --target universal-apple-darwin`.

## Come si aggiorna la pagina

La pagina non si copia a mano: `scripts/prepare-web.mjs` parte da solo prima di `dev` e `build` e crea `dist/` (cartella generata, non va modificata) generando il sito con `../scripts/build.mjs` e partendo dalla home italiana `../site/index.html` (la sorgente è `../src/index.html`). Quindi basta rifare la build dopo aver cambiato la pagina.

Lo script adatta la copia così:

1. **pdf.js e font.** Li serve già il sito stesso (`/vendor/pdfjs/<versione>/` e `/fonts/`, copiati da `../scripts/build.mjs` dai pacchetti npm `pdfjs-dist` e Fontsource del `package.json` nella radice): l'app copia le stesse cartelle in `dist/`. Serve quindi `npm ci` (o `npm install`) anche nella radice del repository.
2. **Condivisione con link nascosta** (vedi sotto) e la frase della pagina iniziale "a meno che tu non scelga di condividerli" tolta.
3. **Solo sito:** statistiche di visita tolte; invito all'altra lingua, collegamenti alle pagine per professione, all'app per computer, a privacy e termini e selettore di lingua tolti; la firma "Una trovata di 16bit" resta come testo senza link (un link porterebbe via la finestra dell'app).
4. **Aspetto da app** (vedi sotto).
5. File locali citati dalla pagina (icone, manifest, ecc.) copiati se esistono.

Ogni sostituzione deve trovare il suo testo esattamente una volta: se la pagina cambia in quei punti, la build si ferma con un messaggio invece di produrre un'app che va in rete. Alla fine, se nella pagina o in `fonts.css` resta un indirizzo di rete inatteso, la build si ferma con l'elenco.

## Aspetto da app

L'app non mostra la pagina di presentazione del sito ma una schermata iniziale tranquilla: titolo breve "Confronta due documenti", una riga di aiuto, le due zone per i file e, in fondo, solo "Una trovata di 16bit" con il logo, piccola e senza link. `prepare-web.mjs` sostituisce titolo e sottotitolo del sito e aggiunge in `<head>` uno stile e uno script che mettono la classe `app` su `<html>` (più `mac` su macOS e `fullscreen` a schermo intero); tutto il resto è CSS legato a quella classe, quindi il markup resta quello del sito:

- nascosti: sezioni per professione (`.uses`), tutto ciò che ha la classe `site-only` (per esempio le funzioni principali con le immagini), slogan e ogni altro elemento del piè di pagina tranne la firma;
- testo non selezionabile sui comandi (resta selezionabile nei documenti, nell'elenco delle modifiche e nei campi), freccia normale invece della manina su pulsanti e zone dei file, niente rimbalzo dello scorrimento, immagini e icone non trascinabili;
- macOS: barra del titolo sovrapposta alla barra dell'app (`titleBarStyle: "Overlay"`, titolo nascosto, pulsanti della finestra centrati nella barra con `trafficLightPosition` 18, 30); la barra lascia 90 px a sinistra per i pulsanti (18 px a schermo intero) e trascina la finestra (`data-tauri-drag-region="deep"` aggiunto dallo script; i controlli che non sono pulsanti, come lo zoom e il menu Scarica, hanno `"false"`). Doppio clic sulla barra: ingrandisce come le altre app. Permessi in `capabilities/default.json`.
- Dimensione minima 820 × 560; dimensione e posizione della finestra ricordate tra un avvio e l'altro (plugin `tauri-plugin-window-state`).

Su Windows e Linux la barra del titolo resta quella del sistema.

## Icona

`npm run icons` usa `../brand/logo/01-fogli-nastro/app-light.svg` (direzione consigliata del marchio), lo mette in un quadrato arrotondato con i margini delle icone macOS e genera con `tauri icon` tutti i formati in `src-tauri/icons/` (`.icns`, `.ico`, PNG). Se la cartella del marchio manca usa `src-tauri/icons/placeholder.svg`. Si può passare un altro SVG: `node scripts/icons.mjs percorso.svg`.

## Cosa funziona e cosa no rispetto al browser

Provato il 30/10/2026 su macOS 26.7 (Apple Silicon), app di sviluppo e app di release.

| Funzione | Stato nell'app |
| --- | --- |
| Confronto docx (regolamento v1 / v2) | Funziona: 55 differenze, le stesse di Chromium. |
| Confronto PDF (contratto v1 / v2) | Funziona: 2 differenze. pdf.js e font caricati dall'app, nessuna richiesta di rete. |
| Senza rete | pdf.js, worker e font sono inclusi: la pagina non carica nulla da internet (verificato con l'elenco delle risorse caricate). |
| Selettore di file ("sceglilo dal computer") | Si apre il pannello di macOS; la scelta del file dal pannello non è stata provata fino in fondo. |
| Trascinamento di file nella finestra | Il trascinamento nativo di Tauri è disattivato (`dragDropEnabled: false`), così la pagina riceve gli eventi come nel browser. Verificato con un evento di rilascio dentro la pagina; un trascinamento vero dal Finder va ancora provato a mano. |
| Scarica in Word (con revisioni) | Funziona: il file finisce direttamente in **Download** senza chiedere dove salvarlo (comportamento predefinito di Tauri), con lo stesso nome del browser. Se esiste già, macOS aggiunge " (1)". Il file passa i controlli di `tests/check_tracked.py` (anche con pandoc). |
| Scarica PDF | Funziona, con differenze. `window.print` apre il pannello di stampa di macOS (serve il permesso `core:webview:allow-print`, già nella configurazione); `beforeprint` arriva con i fogli pronti, da "PDF" si salva il file, poi `afterprint` ripristina la pagina e il titolo (il nome proposto è "Raffronto - <nome>"). Differenze rispetto a Chrome: le pagine dei PDF sono **immagini** e non testo vettoriale (il trucco del canvas ridisegnato in `beforeprint` è di Chrome: circa 330 KB per pagina invece di 25 KB, testo non selezionabile nelle pagine PDF; intestazione ed elenco delle modifiche restano testo); il formato del foglio è sempre **A4 verticale** anche per "Affiancati" (WebKit ignora `@page size`, come Safari: si può scegliere l'orientamento nel pannello); nel testo copiato dal PDF le legature (fi, ff) possono uscire male. In una delle prove automatiche (app avviata in secondo piano) il pannello di stampa non è comparso: da tenere d'occhio. |
| Condivisione con link | Nascosta (vedi sotto). |
| Tema chiaro/scuro, scorciatoie, scorrimento sincronizzato | Come nel browser (stesso codice). |

### Perché la condivisione è nascosta

Nell'app non c'è `share.php`, e puntare a `https://tools.16bit.cloud/raffronto/share.php` non basta: la pagina dell'app ha un'altra origine (`tauri://localhost`), quindi il browser integrato manda prima una richiesta di controllo (CORS) a cui `share.php` oggi risponde 405, e il caricamento fallisce. Inoltre il link creato punterebbe all'app (`tauri://localhost/#s=…`) e non al sito, e chi lo riceve lo apre comunque nel browser. Per abilitarla servirebbero: intestazioni CORS e risposta a `OPTIONS` in `share.php` (oppure le richieste fatte dal lato Rust con il plugin http di Tauri), e la base del link fissata al sito. Rimandato finché non serve davvero.

## Prova automatica

`node scripts/check-app.mjs` avvia l'app di sviluppo (`src-tauri/target/debug/raffronto`, da costruire prima con `cd src-tauri && cargo build` o `npm run dev`), carica i documenti sintetici di `../tests/fixtures` con un evento di rilascio dentro la pagina e controlla: font e pdf.js locali, nessuna risorsa dalla rete, regolamento v1 / v2 con 55 differenze, contratto PDF con 2, condivisione nascosta, "Scarica in Word" (il file viene spostato da Download in `/tmp/raffronto-desktop`, o `OUT=`, e controllato con `tests/check_tracked.py`), nessun errore nella pagina. Con `--print` apre anche "Scarica PDF > Affiancati" e aspetta che una persona salvi il PDF o annulli nel pannello di stampa.

Come funziona: solo nell'app di sviluppo (mai in quella di release) la console della pagina viene scritta nel terminale e, con la variabile `RAFFRONTO_DEBUG_PORT`, l'app esegue gli script ricevuti su quella porta locale (`src-tauri/src/debug.rs`). Il pannello di selezione dei file, il pannello di stampa e un trascinamento vero dal Finder richiedono mouse e tastiera reali: vanno provati a mano. La finestra dell'app deve restare visibile durante la prova: se è coperta da altre finestre WebKit sospende la pagina (`document.visibilityState` "hidden", niente `requestAnimationFrame`) e i controlli restano fermi su "Leggo i documenti…".

## Build su GitHub e download

Download per gli utenti: https://raffronto.app/scarica (in inglese `/en/download`), che propone il file giusto per il sistema di chi visita; tutte le release su https://github.com/16bitsrl/raffronto/releases/latest. Il job `publish` carica anche copie dei file con nomi fissi senza versione (`Raffronto-mac-arm64.dmg`, `Raffronto-mac-x64.dmg`, `Raffronto-windows-x64-setup.exe`, `Raffronto-windows-x64.msi`, `Raffronto-windows-arm64-setup.exe`, `Raffronto-linux-x64.AppImage`, `Raffronto-linux-x64.deb`, `Raffronto-linux-arm64.AppImage`, `Raffronto-linux-arm64.deb`), così la pagina punta sempre a `releases/latest/download/<nome>`; se ne manca uno la release non viene pubblicata.

`.github/workflows/desktop.yml` (GitHub Actions, `tauri-apps/tauri-action@v1`) costruisce l'app su sei macchine:

| Sistema | Macchina | File |
| --- | --- | --- |
| macOS Apple Silicon | `macos-latest`, `aarch64-apple-darwin` | `.dmg` |
| macOS Intel | `macos-latest`, `x86_64-apple-darwin` | `.dmg` |
| Windows x64 | `windows-latest`, `x86_64-pc-windows-msvc` | `.msi`, `-setup.exe` (NSIS) |
| Windows ARM64 | `windows-latest`, `aarch64-pc-windows-msvc` | solo `-setup.exe` (WiX non crea MSI per ARM64) |
| Linux x64 | `ubuntu-22.04` | AppImage, `.deb` |
| Linux ARM64 | `ubuntu-24.04-arm` | AppImage, `.deb` |

- **Rilascio:** si aggiorna `version` in `src-tauri/tauri.conf.json` (e per ordine in `package.json` e `Cargo.toml`), poi si crea e si invia il tag: `git tag v0.2.0 && git push origin v0.2.0`. Il flusso controlla che il tag corrisponda alla versione, crea una release in bozza, ci carica i file di tutte le build e la pubblica solo se sono andate tutte bene.
- **Prova senza rilascio:** Actions > Desktop > Run workflow. I file restano come artefatti dell'esecuzione (anche nei rilasci).
- La pagina si genera dalla radice del repository (`scripts/build.mjs`, `src/`) con Node 22; pdf.js e i font vengono da `npm ci` nella radice, la CLI di Tauri da `npm ci` in `desktop/`.
- Linux ARM64 è costruito su Ubuntu 24.04: l'AppImage richiede una glibc almeno di quella versione (per sistemi più vecchi si può passare a `ubuntu-22.04-arm`).

### Firma (oggi non firmata)

Oggi su macOS c'è solo la firma ad hoc (`APPLE_SIGNING_IDENTITY: "-"` nel flusso): l'app si apre con clic destro > Apri la prima volta, invece del messaggio "è danneggiata". Su Windows SmartScreen mostra l'avviso "editore sconosciuto". Per firmare, aggiungere questi segreti al repository (Settings > Secrets and variables > Actions) e togliere il commento alle righe corrispondenti nel passo `tauri-action`:

- **macOS, firma** (certificato "Developer ID Application" dell'account Apple Developer): `APPLE_CERTIFICATE` (il `.p12` esportato dal Portachiavi, in base64), `APPLE_CERTIFICATE_PASSWORD`, `APPLE_SIGNING_IDENTITY` (per esempio `Developer ID Application: 16bit S.r.l. (TEAMID)`, al posto di `"-"`).
- **macOS, notarizzazione**, una delle due: `APPLE_ID`, `APPLE_PASSWORD` (password specifica per l'app), `APPLE_TEAM_ID`; oppure una chiave API di App Store Connect: `APPLE_API_ISSUER`, `APPLE_API_KEY` e il file `.p8` scritto da un passo precedente in un percorso passato come `APPLE_API_KEY_PATH`.
- **Windows:** con un certificato classico `.pfx`, segreti `WINDOWS_CERTIFICATE` (base64) e `WINDOWS_CERTIFICATE_PASSWORD`, un passo che lo importa nell'archivio certificati prima della build e `bundle.windows.certificateThumbprint` in `tauri.conf.json`; con Azure Trusted Signing (oggi la via più semplice) `bundle.windows.signCommand` e i segreti `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`. Va fatto per entrambe le build Windows.

## Windows e Linux

La configurazione (`src-tauri/tauri.conf.json`, `"targets": "all"`, icone `.ico` e PNG) è già pronta; la build va fatta sulla piattaforma di destinazione (in pratica con il flusso di GitHub descritto sopra):

- Windows: `npm run build` produce installatori `.msi` e `.exe` (NSIS). Usa WebView2 (Chromium): la stampa dovrebbe comportarsi come in Chrome, anche per le pagine PDF vettoriali, ma va provata.
- Linux: servono le dipendenze di WebKitGTK (vedi la guida di Tauri); produce `.deb`, `.rpm` e AppImage. Stampa e download sono da provare.

Non ancora provate a mano: il flusso le costruisce, ma l'uso vero (stampa, download, trascinamento) va verificato.

## Passi futuri (non fatti)

- **Firma e notarizzazione macOS, firma Windows:** il flusso è pronto, mancano certificati e segreti (vedi "Firma (oggi non firmata)").
- **Aggiornamenti automatici** con il plugin updater di Tauri (richiede firma degli aggiornamenti e un indirizzo da cui scaricarli).
- **Scarica PDF migliore su macOS**: si potrebbe generare il PDF dal lato Rust (stampa di WebKit con orientamento scelto, o `createPDF`) invece del pannello di stampa, per avere il foglio orizzontale in "Affiancati".
- **Salvataggio del Word con "Salva con nome"** (plugin dialog e fs) se si preferisce scegliere la cartella invece di Download.
