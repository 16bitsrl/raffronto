// Privacy policy and terms of use, in their language. scripts/build.mjs puts each one in src/legal.html and
// writes site/<path>index.html; `link` is the label in the footer of the app. Keep them short and true to how
// the app works (src/index.html, cloudflare/src/index.ts, docs/README.md): update them when that changes.

const updated = { it: '30 ottobre 2026', en: '30 October 2026' };
const company = {
  it: '16bit S.r.l., via Filippo Tajani 9, 20133 Milano, partita IVA 09662570960',
  en: '16bit S.r.l., via Filippo Tajani 9, 20133 Milano, Italy, VAT number IT09662570960',
};
const email = '<a href="mailto:hello@16bit.it">hello@16bit.it</a>';

export const legal = [
  {
    id: 'privacy',
    it: {
      path: '/privacy/', link: 'Privacy',
      title: 'Informativa sulla privacy',
      description: 'Come Raffronto tratta i tuoi dati: i documenti restano nel tuo browser, i link condivisi sono cifrati, le statistiche non usano cookie.',
      updated: updated.it,
      body: `
<h2>Chi è il titolare</h2>
<p>Raffronto è un servizio gratuito di ${company.it}. Per qualsiasi domanda sui tuoi dati scrivi a ${email}.</p>

<h2>I tuoi documenti</h2>
<p>I documenti che carichi vengono letti e confrontati nel tuo browser. Se non scegli di condividerli, non li riceviamo e non li conserviamo.</p>

<h2>I link condivisi</h2>
<p>Se scegli di condividere un confronto, il browser cifra i due documenti, con i loro nomi e date, prima di inviarli. A noi arriva solo una copia illeggibile: la chiave per aprirla sta nel link, nella parte dopo il simbolo #, che il browser non trasmette nelle richieste al server: non riceviamo la chiave e non possiamo aprirla. Dopo 7 giorni il link smette di funzionare; la copia viene cancellata in automatico dopo 8 giorni, di solito entro le 24 ore successive. Chiunque abbia il link può aprire il confronto: mandalo solo a chi deve vederlo.</p>
<p>Per evitare abusi conserviamo un codice ricavato dall’indirizzo IP di chi crea un link, con gli orari dei tentativi, solo per limitare quanti link crea in un’ora. L’indirizzo IP non viene salvato. Il codice viene cancellato in automatico un giorno dopo l’ultimo tentativo, di solito entro le 24 ore successive.</p>

<h2>Statistiche</h2>
<p>Contiamo le visite con uno strumento di statistica che gestiamo noi, su un nostro server in Italia, con copie di sicurezza presso Backblaze nei Paesi Bassi. Non usa cookie e non serve a creare profili. Registra la pagina visitata, il sito da cui arrivi, browser, sistema operativo e tipo di dispositivo, dimensioni dello schermo, lingua e posizione approssimativa (paese e città), ricavata dall’indirizzo IP. Per contare le visite distingue le sessioni con un codice ricavato dall’indirizzo IP e dai dati del browser; l’indirizzo IP non viene salvato nelle statistiche. Contiamo anche quando fai un confronto, crei o apri un link condiviso, indicando solo il tipo di file (Word o PDF): mai nomi, contenuti o la parte del link dopo #. Conserviamo le statistiche per non più di due anni e le copie di sicurezza per 30 giorni.</p>

<h2>Chi ci aiuta a offrire il servizio</h2>
<ul>
<li><b>Cloudflare</b> ospita il sito sulla sua rete mondiale; le copie cifrate dei link condivisi sono conservate in Europa occidentale. Come ogni servizio di hosting riceve l’indirizzo IP e i dati tecnici delle richieste e li tiene nei suoi registri per pochi giorni, per sicurezza e funzionamento.</li>
<li><b>Google Fonts</b> fornisce i caratteri della pagina e <b>jsDelivr</b> il programma che legge i PDF. Il browser li scarica direttamente da loro, che quindi ricevono il tuo indirizzo IP. Non ricevono i tuoi documenti.</li>
</ul>
<p>Questi fornitori possono trattare l’indirizzo IP anche fuori dallo Spazio economico europeo. Cloudflare e Google aderiscono al Data Privacy Framework UE-USA, riconosciuto adeguato dalla Commissione europea; jsDelivr distribuisce i file attraverso reti di fornitori in tutto il mondo.</p>

<h2>Cosa resta sul tuo dispositivo</h2>
<p>Nessun cookie. Il browser ricorda il tema chiaro o scuro, la lingua che hai scelto e se hai già visto la spiegazione delle revisioni, e conserva una copia dell’app per usarla anche senza connessione. Puoi cancellare tutto dalle impostazioni del browser.</p>

<h2>Perché e i tuoi diritti</h2>
<p>Usiamo i dati necessari a darti il servizio che chiedi, come i link condivisi: senza, quella funzione non può funzionare. Per la sicurezza, il caricamento della pagina e le statistiche ci basiamo sul nostro legittimo interesse a prevenire abusi, a far funzionare il sito e a capire quanto viene usato. Nei casi previsti dalla legge puoi chiederci di accedere ai tuoi dati, correggerli, cancellarli, limitarne l’uso, opporti al trattamento o riceverli in un formato utilizzabile altrove, scrivendo a ${email}. Puoi anche rivolgerti al Garante per la protezione dei dati personali (<a href="https://www.garanteprivacy.it/">garanteprivacy.it</a>).</p>
`,
    },
    en: {
      path: '/en/privacy/', link: 'Privacy',
      title: 'Privacy policy',
      description: 'How Raffronto handles your data: documents stay in your browser, shared links are encrypted, statistics use no cookies.',
      updated: updated.en,
      body: `
<h2>Who we are</h2>
<p>Raffronto is a free service by ${company.en}. For any question about your data, write to ${email}.</p>

<h2>Your documents</h2>
<p>The documents you drop in are read and compared in your browser. Unless you choose to share them, we do not receive or store them.</p>

<h2>Shared links</h2>
<p>If you choose to share a comparison, your browser encrypts the two documents, with their names and dates, before sending them. We only receive an unreadable copy: the key to open it is in the link, in the part after the # sign, which browsers do not include in requests to the server: we do not receive the key and cannot open it. The link stops working after 7 days; the copy is deleted automatically after 8 days, usually within another 24 hours. Anyone with the link can open the comparison: send it only to the people who need to see it.</p>
<p>To prevent abuse we keep a code derived from the IP address of whoever creates a link, with the times of the attempts, only to limit how many links it creates in an hour. The IP address itself is not stored. The code is deleted automatically one day after the last attempt, usually within another 24 hours.</p>

<h2>Statistics</h2>
<p>We count visits with a statistics tool we run ourselves, on our own server in Italy, with backups at Backblaze in the Netherlands. It uses no cookies and is not used to build profiles. It records the page visited, the site you came from, your browser, operating system and device type, screen size, language and approximate location (country and city), worked out from your IP address. To count visits it tells sessions apart with a code derived from your IP address and browser details; the IP address itself is not stored in the statistics. We also count when you compare, create or open a shared link, noting only the kind of file (Word or PDF): never names, contents or the part of the link after #. We keep statistics for no more than two years and backups for 30 days.</p>

<h2>Who helps us run the service</h2>
<ul>
<li><b>Cloudflare</b> hosts the site on its worldwide network; the encrypted copies of shared links are stored in Western Europe. Like any hosting service it receives your IP address and the technical details of each request, and keeps them in its logs for a few days for security and operation.</li>
<li><b>Google Fonts</b> provides the typefaces of the page and <b>jsDelivr</b> the program that reads PDFs. Your browser downloads them directly from them, so they receive your IP address. They do not receive your documents.</li>
</ul>
<p>These providers may process your IP address outside the European Economic Area. Cloudflare and Google take part in the EU-US Data Privacy Framework, which the European Commission recognises as adequate; jsDelivr delivers its files through networks of providers worldwide.</p>

<h2>What stays on your device</h2>
<p>No cookies. Your browser remembers the light or dark theme, the language you chose and whether you have already seen the explanation of tracked changes, and keeps a copy of the app so it also works offline. You can clear all of it from your browser settings.</p>

<h2>Why, and your rights</h2>
<p>We use the data needed to give you the service you ask for, such as shared links: without it, that feature cannot work. For security, loading the page and statistics we rely on our legitimate interest in preventing abuse, running the site and understanding how much it is used. Where the law provides, you can ask us to access, correct or delete your data, restrict its use, object to its processing or receive it in a portable format, by writing to ${email}. You can also complain to the Italian data protection authority, the Garante per la protezione dei dati personali (<a href="https://www.garanteprivacy.it/">garanteprivacy.it</a>).</p>
`,
    },
  },
  {
    id: 'terms',
    it: {
      path: '/termini/', link: 'Termini',
      title: 'Termini di utilizzo',
      description: 'Le condizioni per usare Raffronto, il servizio gratuito di 16bit per confrontare documenti Word e PDF.',
      updated: updated.it,
      body: `
<h2>Il servizio</h2>
<p>Raffronto è un servizio gratuito di ${company.it}. Usandolo accetti questi termini. Possiamo modificare, sospendere o chiudere il servizio per esigenze tecniche, di sicurezza o organizzative, con un ragionevole preavviso sul sito salvo urgenze.</p>

<h2>Il risultato</h2>
<p>Facciamo del nostro meglio perché il confronto sia preciso, ma il risultato può contenere errori. Il confronto può non rilevare ogni differenza, per esempio nella formattazione, nei PDF scansionati o in impaginazioni complesse. Per i documenti importanti controlla sempre il risultato sugli originali.</p>

<h2>I tuoi documenti e i tuoi link</h2>
<p>Usa solo documenti che hai il diritto di usare. Sei responsabile dei link condivisi che crei e delle persone a cui li mandi. Non usare il servizio per scopi illeciti e non cercare di sovraccaricarlo o aggirarne i limiti.</p>

<h2>Responsabilità</h2>
<p>Questi termini non escludono né limitano le responsabilità previste dalla legge, comprese quelle per dolo o colpa grave, né i diritti e i rimedi riconosciuti ai consumatori.</p>

<h2>Modifiche e legge applicabile</h2>
<p>Gli aggiornamenti di questi termini valgono per l’uso successivo alla pubblicazione e non cambiano le condizioni dei link già creati; la data in alto indica la versione in vigore. Si applica la legge italiana, senza togliere ai consumatori le tutele inderogabili del paese in cui vivono. Per i consumatori resta competente il giudice previsto dalle norme a loro tutela; negli altri casi valgono le regole ordinarie.</p>

<h2>Contatti</h2>
<p>Scrivi a ${email}. Per come trattiamo i dati, leggi l’<a href="/privacy/">informativa sulla privacy</a>.</p>
`,
    },
    en: {
      path: '/en/terms/', link: 'Terms',
      title: 'Terms of use',
      description: 'The conditions for using Raffronto, the free service by 16bit for comparing Word and PDF documents.',
      updated: updated.en,
      body: `
<h2>The service</h2>
<p>Raffronto is a free service by ${company.en}. By using it you accept these terms. We may change, suspend or close the service for technical, security or operational reasons, with reasonable notice on the site unless it is urgent.</p>

<h2>The result</h2>
<p>We do our best to make the comparison accurate, but the result may contain errors. A comparison may miss some differences, for example in formatting, in scanned PDFs or in complex layouts. For important documents, always check the result against the originals.</p>

<h2>Your documents and your links</h2>
<p>Only use documents you have the right to use. You are responsible for the shared links you create and for the people you send them to. Do not use the service for unlawful purposes and do not try to overload it or get around its limits.</p>

<h2>Liability</h2>
<p>These terms do not exclude or limit any liability imposed by law, including for wilful misconduct or gross negligence, or the rights and remedies the law gives consumers.</p>

<h2>Changes and governing law</h2>
<p>Updates to these terms apply to use after they are published and do not change the conditions of links already created; the date at the top shows the version in force. Italian law applies, without depriving consumers of the mandatory protections of the country where they live. Consumers keep the courts available under the rules that protect them; in other cases the ordinary rules apply.</p>

<h2>Contact</h2>
<p>Write to ${email}. For how we handle data, read the <a href="/en/privacy/">privacy policy</a>.</p>
`,
    },
  },
];

// labels of the legal pages themselves, per language
export const legalUi = {
  it: { updated: 'Aggiornato il', home: 'Torna a Raffronto', theme: 'Tema chiaro o scuro', themeLabel: 'Cambia tema' },
  en: { updated: 'Last updated', home: 'Back to Raffronto', theme: 'Light or dark theme', themeLabel: 'Change theme' },
};
