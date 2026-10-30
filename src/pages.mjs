// The pages of the site: the same app, with its own address, title, opening and sections for each language.
// scripts/build.mjs turns every page into site/<path>index.html. Texts here are already in their language.

export const pages = [
  {
    id: 'home',
    it: {
      path: '/',
      title: 'Raffronto · confronta due documenti',
      description: 'Ogni modifica, anche quella che non ti hanno detto. Confronta due versioni di un documento Word o PDF e vedi affiancate tutte le differenze, pagina per pagina. I file restano sul tuo computer.',
      h1: 'Scopri cosa <del>è rimasto uguale</del> <ins>è cambiato</ins> tra due versioni.',
      lede: 'Carica l’originale e la nuova versione di un contratto, di uno statuto o di qualsiasi documento Word o PDF. Le differenze compaiono affiancate, pagina per pagina, collegate tra loro.',
    },
    en: {
      path: '/en/',
      title: 'Raffronto · compare two documents',
      description: 'Every change, even the ones nobody told you about. Compare two versions of a Word or PDF document and see every difference side by side, page by page. Your files stay on your computer.',
      h1: 'See what <del>stayed the same</del> <ins>changed</ins> between two versions.',
      lede: 'Drop in the original and the new version of a contract, a set of bylaws or any Word or PDF document. The differences appear side by side, page by page, linked to each other.',
    },
  },
  {
    id: 'lawyers',
    it: {
      path: '/avvocati/',
      nav: 'Avvocati',
      title: 'Confrontare due versioni di un contratto · Raffronto per avvocati',
      description: 'Confronta la bozza che hai mandato con quella che ti è tornata, in Word o PDF: ogni modifica affiancata ed evidenziata, anche senza revisioni attive. Gratuito, i documenti restano sul tuo computer.',
      h1: 'Dicono di aver cambiato <ins>solo l’articolo 7</ins>.',
      lede: 'Carica la bozza che hai mandato e quella che ti è tornata. Raffronto mostra ogni parola aggiunta, tolta o spostata, anche dove nessuno ha attivato le revisioni, e ti prepara un Word con revisioni da rimandare.',
      h2: 'Per chi negozia contratti',
      cards: [
        ['Bozze senza revisioni', 'La nuova versione arriva pulita, senza revisioni attive? Il confronto si fa sul testo, quindi trovi anche le modifiche che nessuno ha segnato.'],
        ['Word contro PDF', 'Hai il tuo Word e la loro versione in PDF, magari firmata: si confrontano lo stesso, con firme, timbri e note in più o in meno segnalati.'],
        ['Revisioni da rimandare', 'Scarica la nuova versione come Word con revisioni: ogni differenza diventa una modifica da accettare o rifiutare, con la formattazione originale.'],
      ],
    },
    en: {
      path: '/en/lawyers/',
      nav: 'Lawyers',
      title: 'Compare two versions of a contract · Raffronto for lawyers',
      description: 'Compare the draft you sent with the one that came back, in Word or PDF: every change side by side and highlighted, even without tracked changes. Free, your documents stay on your computer.',
      h1: 'They say they only changed <ins>clause 7</ins>.',
      lede: 'Drop in the draft you sent and the one that came back. Raffronto shows every word added, removed or moved, even where nobody turned on track changes, and prepares a Word file with tracked changes to send back.',
      h2: 'For people who negotiate contracts',
      cards: [
        ['Drafts without tracked changes', 'The new version came back clean, with no tracked changes? The comparison works on the text, so you also find the edits nobody marked.'],
        ['Word against PDF', 'You have your Word file and their PDF, maybe signed: they compare all the same, with signatures, stamps and notes that were added or removed flagged too.'],
        ['Tracked changes to send back', 'Download the new version as a Word file with tracked changes: every difference becomes an edit to accept or reject, with the original formatting.'],
      ],
    },
  },
  {
    id: 'notaries',
    it: {
      path: '/notai/',
      nav: 'Notai',
      title: 'Confrontare bozza e atto, statuti prima e dopo · Raffronto per notai',
      description: 'Confronta la bozza condivisa con le parti e il testo definitivo, lo statuto vigente e quello modificato, il PDF firmato e il Word di partenza. Gratuito, i documenti restano sul tuo computer.',
      h1: 'Tra la bozza approvata e l’atto da firmare, <ins>cosa è cambiato</ins>?',
      lede: 'Confronta la bozza condivisa con le parti e il testo definitivo, lo statuto vigente e quello modificato, il PDF firmato e il Word di partenza. Ogni differenza è affiancata e collegata, pagina per pagina.',
      h2: 'Per lo studio notarile',
      cards: [
        ['Statuti e patti', 'Statuto vigente e testo con le modifiche proposte: vedi articolo per articolo cosa entra e cosa esce, con la numerazione automatica di Word.'],
        ['Atti firmati in PDF', 'Raffronto legge anche i PDF firmati digitalmente: segnala le firme aggiunte o tolte e mostra chi ha firmato. Non verifica la validità delle firme.'],
        ['Versione finale con modifiche', 'Scarica un PDF con il testo definitivo, le aggiunte in verde e le parti tolte barrate in rosso, da allegare o da mandare alle parti.'],
      ],
    },
    en: {
      path: '/en/notaries/',
      nav: 'Notaries',
      title: 'Compare a draft with the final deed · Raffronto for notaries',
      description: 'Compare the draft shared with the parties and the final text, the current bylaws and the amended ones, the signed PDF and the original Word file. Free, your documents stay on your computer.',
      h1: 'Between the approved draft and the deed to sign, <ins>what changed</ins>?',
      lede: 'Compare the draft shared with the parties and the final text, the current bylaws and the amended ones, the signed PDF and the original Word file. Every difference is side by side and linked, page by page.',
      h2: 'For notarial offices',
      cards: [
        ['Bylaws and agreements', 'Current bylaws and the text with the proposed amendments: see article by article what goes in and what comes out, with Word’s automatic numbering.'],
        ['Signed PDFs', 'Raffronto also reads digitally signed PDFs: it flags signatures that were added or removed and shows who signed. It does not check whether signatures are valid.'],
        ['Final version with changes', 'Download a PDF of the final text with additions in green and removed parts struck through in red, ready to attach or send to the parties.'],
      ],
    },
  },
  {
    id: 'tenders',
    it: {
      path: '/gare-e-appalti/',
      nav: 'Gare e appalti',
      title: 'Confrontare bandi, capitolati e rettifiche · Raffronto per gare e appalti',
      description: 'Confronta disciplinare, capitolato o schema di contratto con la versione rettificata e trova ogni riga cambiata, anche Word contro PDF. Gratuito, i documenti restano sul tuo computer.',
      h1: 'Il capitolato è stato rettificato. <ins>Dove?</ins>',
      lede: 'Confronta disciplinare, capitolato o schema di contratto con la versione rettificata, oppure la tua offerta con le richieste di chiarimento. Anche documenti di decine di pagine, anche Word contro PDF.',
      h2: 'Per chi partecipa alle gare',
      cards: [
        ['Rettifiche', 'La stazione appaltante ripubblica il capitolato: in pochi secondi vedi tutte le righe cambiate, non solo quelle che l’avviso dichiara.'],
        ['Documenti lunghi', 'Elenco delle modifiche con filtri, conteggio delle parole aggiunte e tolte, pagina di ogni modifica e salto dall’una all’altra con i tasti J e K.'],
        ['PDF dal portale', 'Il PDF scaricato dalla piattaforma si confronta con il tuo Word, con immagini, firme e timbri in più o in meno segnalati.'],
      ],
    },
    en: {
      path: '/en/tenders/',
      nav: 'Tenders',
      title: 'Compare tender documents and amendments · Raffronto for tenders',
      description: 'Compare tender specifications or the draft contract with the amended version and find every line that changed, even Word against PDF. Free, your documents stay on your computer.',
      h1: 'The tender specifications were amended. <ins>Where?</ins>',
      lede: 'Compare the specifications or the draft contract with the amended version, or your bid with the latest clarifications. Even documents dozens of pages long, even Word against PDF.',
      h2: 'For people who bid on tenders',
      cards: [
        ['Amendments', 'The contracting authority republishes the specifications: in a few seconds you see every line that changed, not just the ones the notice mentions.'],
        ['Long documents', 'A list of changes with filters, a count of words added and removed, the page of every change, and J and K to jump from one to the next.'],
        ['PDFs from the portal', 'The PDF downloaded from the platform compares with your Word file, with images, signatures and stamps that were added or removed flagged too.'],
      ],
    },
  },
  {
    id: 'translators',
    it: {
      path: '/traduttori/',
      nav: 'Traduttori',
      title: 'Trovare cosa è cambiato nel testo da tradurre · Raffronto per traduttori',
      description: 'Confronta la vecchia e la nuova versione del testo originale e traduci solo quello che è cambiato, oppure vedi cosa ha cambiato il revisore. Gratuito, i testi restano sul tuo computer.',
      h1: 'Il cliente ha aggiornato il testo. <ins>Traduci solo</ins> quello che è cambiato.',
      lede: 'Confronta la vecchia e la nuova versione del documento originale e trovi subito le frasi da tradurre di nuovo. Oppure confronta la tua traduzione con quella rivista e vedi cosa ha cambiato il revisore.',
      h2: 'Per chi traduce',
      cards: [
        ['Nuova versione del testo', 'Ogni frase aggiunta, tolta o spostata è nell’elenco con la sua pagina: preventivo e lavoro solo sulle differenze.'],
        ['Revisioni del revisore', 'Il file torna con le revisioni di Word? Raffronto le mostra accettate o rifiutate, come preferisci, e ti dice quante sono.'],
        ['Formati misti', 'Il cliente manda il PDF, tu lavori sul Word: si confrontano lo stesso, pagina per pagina.'],
      ],
    },
    en: {
      path: '/en/translators/',
      nav: 'Translators',
      title: 'Find what changed in the text to translate · Raffronto for translators',
      description: 'Compare the old and the new version of the source text and translate only what changed, or see what the reviewer changed. Free, your texts stay on your computer.',
      h1: 'The client updated the text. <ins>Translate only</ins> what changed.',
      lede: 'Compare the old and the new version of the source document and find the sentences to translate again right away. Or compare your translation with the reviewed one and see what the reviewer changed.',
      h2: 'For translators',
      cards: [
        ['A new version of the text', 'Every sentence added, removed or moved is in the list with its page: quote and work only on the differences.'],
        ['The reviewer’s tracked changes', 'The file came back with Word tracked changes? Raffronto shows them accepted or rejected, as you prefer, and tells you how many there are.'],
        ['Mixed formats', 'The client sends a PDF, you work in Word: they compare all the same, page by page.'],
      ],
    },
  },
];

// shared by every page of a language
export const languages = {
  it: {
    locale: 'it_IT', name: 'Italiano', image: '/social.png',
    imageAlt: 'Raffronto: scopri cosa è cambiato tra due versioni di un documento.',
    slogan: 'Ogni modifica, anche quella che non ti hanno detto.',
    hint: 'Raffronto è disponibile anche in italiano',
    os: 'Tutti, nel browser',
  },
  en: {
    locale: 'en_GB', name: 'English', image: '/social-en.png',
    imageAlt: 'Raffronto: see what changed between two versions of a document.',
    slogan: 'Every change, even the ones nobody told you about.',
    hint: 'Raffronto is also available in English',
    os: 'Any, in the browser',
  },
};
