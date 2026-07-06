# Capitolo 3 — Ristrutturare o ricostruire

**Livello:** Fondamentale
**Tempo stimato:** 40–50 minuti
**Argomenti del manuale:** che cosa significa «immutabile» (3.1), le due strade del cambiamento: in-place e replace (3.2), governare la sostituzione: il blocco lifecycle (3.3), perché l'immutabilità riduce il rischio (3.4), il filo che lega la Parte 1 (3.5)

## L'idea

Davanti a un edificio da cambiare, l'architetto ha due strade: ristrutturare
(l'edificio resta in piedi, si cambia un impianto) o demolire e ricostruire
(un edificio nuovo prende il posto del vecchio). L'infrastruttura funziona
allo stesso modo, e la cosa notevole è che *non decidi tu* quale strada si
prende: la conosce il provider, attributo per attributo — e il piano te la
annuncia sempre in anticipo, con una segnaletica precisa che in questo
esercizio impari a leggere.

Qui il "server" è per la prima volta una cosa viva: un container Docker con
dentro nginx. Gli cambi la memoria e lo guardi restare lo stesso oggetto
(ristrutturazione, in-place). Poi gli cambi la versione dell'immagine e lo
guardi *morire e rinascere* (ricostruzione, replace): dentro quel container
nessuno è mai entrato ad aggiornare nginx — questo è, alla lettera,
l'immutabilità. Infine prendi in mano il blocco lifecycle e governi la
sostituzione: prima inverti l'ordine (costruisci il nuovo, poi demolisci il
vecchio), poi metti il fermo di sicurezza che blocca qualunque demolizione —
e scopri che blocca anche più di quanto pensassi.

## Obiettivi

Alla fine saprai:

- leggere nel piano la strada scelta: la tilde dell'update in-place, il -/+
  del replace, il marcatore che dice esattamente *quale* attributo forza la
  sostituzione;
- spiegare perché è il provider a decidere la strada, attributo per
  attributo;
- invertire l'ordine della sostituzione con create_before_destroy, e dire
  quale condizione sull'identità lo rende possibile;
- usare prevent_destroy come fermo di sicurezza, sapendo che blocca anche i
  replace;
- collegare drift (cap. 1), convergenza (cap. 2) e immutabilità in un unico
  filo.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione e utilizzabile dal tuo utente (docker version deve
  rispondere): è il primo esercizio che usa il provider docker.
- L'esercizio scarica tre piccole immagini nginx alpine (~20 MB l'una).

## Consegna

### Fase 0 — Il primo edificio

Apri start/main.tf: c'è un'immagine nginx a versione fissata e un container
che la usa, con un dettaglio da notare subito: *il nome del container
contiene la versione*. Sembra un vezzo, diventerà decisivo nella Fase 3.

    cd start
    tofu init
    tofu apply
    docker exec cap03-web-1-25-alpine nginx -v

Il tuo edificio è in piedi e dichiara la sua versione: nginx 1.25.

### Fase 1 — La ristrutturazione (in-place)

Annota l'identità dell'edificio:

    docker inspect -f '{{.Id}}' cap03-web-1-25-alpine

In main.tf porta la memoria da 128 a 256. Poi, prima di applicare, leggi:

    tofu plan

Cerca due cose: la riga del titolo — will be updated **in-place** — e la
tilde (~) davanti a memory. È la segnaletica della ristrutturazione:
l'oggetto resterà lo stesso, cambierà un impianto. Applica e verifica:

    tofu apply
    docker inspect -f '{{.Id}}' cap03-web-1-25-alpine

Stesso identico ID: nessuna demolizione. Sotto il cofano il provider ha fatto
l'equivalente di un docker update sul container vivo.

### Fase 2 — La ricostruzione (replace)

Ora cambia la versione: in main.tf porta nginx_version a 1.26-alpine. E di
nuovo, prima di applicare:

    tofu plan

La segnaletica è cambiata completamente: il titolo dice **must be replaced**,
davanti alla risorsa c'è -/+ e, riga per riga, il piano marca con
"# forces replacement" *esattamente quali* attributi non possono cambiare su
un oggetto vivo. Nota anche l'ordine annunciato: destroy and then create
replacement — prima si demolisce, poi si ricostruisce. Applica:

    tofu apply
    docker exec cap03-web-1-26-alpine nginx -v
    docker ps -a

nginx 1.26, e del vecchio container non c'è più traccia. Fermati un momento
su ciò che NON è successo: nessuno è entrato nel container a lanciare un
aggiornamento. L'edificio con dentro nginx 1.25 non esiste più; ne esiste uno
nuovo, colato da un'immagine nuova. Questo è il significato concreto di
«immutabile»: il cambiamento non attraversa l'oggetto, lo sostituisce.

### Fase 3 — Invertire l'ordine (create_before_destroy)

L'ordine di default — demolisci, poi ricostruisci — ha un buco: tra le due
c'è un momento in cui l'edificio non esiste. Il TODO 1 in main.tf ti chiede
di aggiungere al container il blocco lifecycle con create_before_destroy.
Poi porta la versione a 1.27-alpine e leggi il piano:

    tofu plan

Il simbolo è diventato +/- e il titolo dice: create replacement **and then**
destroy. Prima il nuovo, poi la demolizione del vecchio. Applica.

E adesso la domanda importante: perché ha funzionato? Perché i due container
— per un istante vivi insieme — *non condividono nulla dell'identità*: il
nome contiene la versione, quindi il nuovo non è mai in conflitto col
vecchio. Se il nome fosse stato fisso, la costruzione del nuovo sarebbe
fallita sul nome già occupato. È la regola generale di create_before_destroy:
funziona solo se l'identità non è un pezzo unico conteso.

### Fase 4 — Il fermo di sicurezza (prevent_destroy)

Il TODO 2 ti chiede di aggiungere prevent_destroy al blocco lifecycle. Poi
prova a radere tutto al suolo:

    tofu destroy

Errore: Instance cannot be destroyed. Il fermo funziona. Ma ora prova invece
a cambiare ancora la versione dell'immagine in main.tf, e chiedi solo il
piano:

    tofu plan

Stesso errore. Rileggi la Fase 2 e torna qui: un replace *è* una destroy (più
una create) — quindi il fermo blocca anche gli aggiornamenti di versione. È
esattamente quello che vuoi su un database di produzione, ed esattamente
quello che devi ricordarti quando un giorno un innocuo cambio di parametro ti
si rifiuterà di partire.

### Pulizia

Rimuovi la riga prevent_destroy (il fermo si toglie consapevolmente, nel
codice: anche questo è un tratto del modello dichiarativo), riporta la
versione a 1.27-alpine se l'avevi cambiata, poi:

    tofu destroy

Le immagini nginx scaricate restano sul tuo disco (keep_locally: ti evita di
riscaricarle se rifai l'esercizio); se le vuoi togliere, usa docker rmi.

## Criteri di "fatto"

- Dopo la Fase 1 l'ID del container è identico a prima dell'apply (lo hai
  verificato con docker inspect).
- Nel piano della Fase 2 hai individuato il marcatore "# forces replacement"
  e l'annuncio destroy and then create replacement.
- Nel piano della Fase 3 l'ordine è invertito: create replacement and then
  destroy.
- Nella Fase 4 sia il destroy sia il piano del cambio versione falliscono con
  Instance cannot be destroyed.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Le due strade del cambiamento: quale attributo ha viaggiato in-place e
quale ha forzato la sostituzione? Come lo sapevi *prima* di applicare — quale
segnaletica del piano lo annunciava? E perché la strada la decide il
provider, attributo per attributo, e non tu?

**b.** Con create_before_destroy l'ordine si è invertito. Che cosa lo ha reso
possibile in questo esercizio (pensa al nome del container), e che cosa
sarebbe successo con un nome fisso? Poi prevent_destroy: da che cosa ti
protegge, che cosa ti ha sorpreso che bloccasse, e da che cosa NON ti
protegge affatto (pensa a chi cancella a mano, fuori dal modello)?

**c.** Il filo della Parte 1: il cap. 1 ti ha mostrato il drift, il cap. 2 la
convergenza, questo capitolo la sostituzione al posto della riparazione.
Perché ricostruire riduce il rischio rispetto a ristrutturare (pensa alla
storia accumulata dal fiocco di neve, e a che cosa serve per tornare indietro
dopo un aggiornamento andato male)? E che cosa manca ancora al quadro — come
fa lo strumento a sapere *in che ordine* costruire e demolire più risorse
collegate? (È il capitolo 4.)
