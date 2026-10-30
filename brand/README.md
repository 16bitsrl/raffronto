# Il marchio di Raffronto

Quattro esplorazioni generate con lo strumento immagini integrato e tre direzioni ridisegnate a mano in SVG. La tavola `board.html` è autonoma, funziona anche offline e mostra favicon a dimensione reale, icona app, barre chiare e scure, monocromia e slogan.

## Direzioni

1. **Fogli e nastro, consigliata** (`logo/01-fogli-nastro/`). Due margini aperti delimitano le pagine; una curva cambia quota fra le due versioni. Riprende il gesto dei nastri dell’interfaccia. Il logotipo in Instrument Serif richiama la pagina scritta e mantiene un tono professionale senza limitarsi al mondo legale. La riduzione elimina righe di testo e pieghe del foglio per conservare la lettura a 16 px.
2. **R di raccordo** (`logo/02-r-raccordo/`). Una R compatta con due margini nel suo occhiello. Efficace come firma e icona; il confronto fra documenti è meno immediato. Logotipo in Instrument Sans, peso 560.
3. **Traccia** (`logo/03-traccia/`). Due fogli pieni attraversati da un percorso in negativo. Molto robusta in piccolo, ma più astratta. Logotipo in Instrument Sans, peso 560.

L’esplorazione **Margini** resta in archivio: la struttura con grazie tende a essere letta come una H. Le immagini esplorative sono ipotesi, gli SVG sono le versioni finali semplificate, non autotracciati.

## Colori e caratteri

- Blu inchiostro: `#203A59`, colore unico del marchio.
- Carta: `#F8F7F3`, marchio inverso su fondi scuri e fondo chiaro delle icone.
- Fondo scuro: `#161B26`, ripreso dall’app.
- Monocromia: `#000000`. Per il bianco puro sostituire il riempimento con `#FFFFFF`.
- Colori riservati alle modifiche nell’app: rosso `#D7263D`, verde `#0E9F6E`, ambra `#C07D10`. Non applicarli al marchio.

Instrument Serif per il marchio consigliato e i titoli editoriali; Instrument Sans per interfaccia e testi di servizio. Sono i caratteri già usati nel progetto. Copie locali e licenze SIL Open Font License sono in `fonts/`. Le scritte negli SVG sono convertite in tracciati, con spaziatura ottica: non richiedono font installati.

## File e uso

In ogni cartella di direzione:

- `symbol-light.svg`, `symbol-dark.svg`, `symbol-mono.svg`: simbolo su fondo trasparente.
- `logo-light.svg`, `logo-dark.svg`, `logo-mono.svg`: simbolo e logotipo su fondo trasparente. “light” significa uso su fondo chiaro, “dark” uso su fondo scuro.
- `favicon.svg`: simbolo con colore automatico secondo il tema di sistema; `favicon-16.png` e `favicon-32.png`: esportazioni blu su trasparenza. La favicon di Fogli e nastro ha coordinate adattate alla griglia pixel per bordi più nitidi a 16 px.
- `app-light.svg`, `app-dark.svg`: master 512 × 512 con fondo pieno, senza angoli arrotondati incorporati. PNG da 192 e 512 px con gli stessi nomi e suffisso dimensione. Il simbolo resta nel cerchio centrale di sicurezza di raggio 40%, utilizzabile anche con maschere PWA.

Il sistema operativo applica la maschera alle icone. Per un’app desktop, i PNG sono le sorgenti da confezionare nel formato richiesto dalla piattaforma; non sono inclusi pacchetti `.icns` o `.ico`.

Lasciare uno spazio libero di almeno 8 unità della griglia 64 attorno al simbolo. La favicon è l’eccezione intenzionale. Simbolo minimo 16 px; per il logo completo usare almeno 140 px di larghezza e preferibilmente 180 px. Lo slogan resta testo separato: **Ogni modifica, anche quella che non ti hanno detto.** Non inserirlo nella favicon né nell’icona app. La firma “Un progetto di studio 16bit” può accompagnare il marchio nel sito e nei materiali, senza entrare nel simbolo.

## Archivio e verifica

`explorations/` contiene quattro PNG originali e `prompts.json` con i prompt completi. Generazione tramite strumento integrato, nessun invio di documenti dell’utente. Riferimento osservato: confronto locale di `regulation-v1.docx` e `regulation-v2.docx`.

`logo/comparison.png` è una prova raster dei tre sistemi, con favicon reali a 16 px. `build.py` rigenera tutti gli SVG, i PNG e la tavola usando solo i font locali. Richiede fonttools, brotli, cairosvg, Pillow e Cairo. Controllo XML dei 27 SVG, assenza di bitmap e testo dipendente da font, esportazione delle icone e ispezione visiva delle riduzioni. La tavola incorpora gli SVG e le favicon e non carica risorse remote.

Non sono stati modificati i file dell’app. La proposta non include una ricerca di anteriorità o registrabilità del marchio.
