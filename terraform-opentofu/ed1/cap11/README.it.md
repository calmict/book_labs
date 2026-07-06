# Capitolo 11 — Il taccuino e i suoi segreti

**Livello:** Intermedio
**Tempo stimato:** 45–55 minuti
**Argomenti del manuale:** il problema che lo stato risolve (11.1), le tre fonti di verità (11.2), dentro al file di stato (11.3), lo stato contiene dati sensibili (11.4), perché lo stato condiviso cambia tutto (11.5), riepilogo e ponte (11.6)

## L'idea

Da dieci capitoli usi plan e apply, e c'è un personaggio che lavora
nell'ombra a ogni comando: il taccuino dove lo strumento annota che cosa ha
costruito e come si chiamava nel codice. In questo capitolo lo apri e lo
leggi: terraform.tfstate, la mappatura tra gli indirizzi del modello e gli
oggetti reali — con dentro perfino gli archi del grafo.

Poi tre scoperte in crescendo. La prima scotta: crei una password marcata
sensitive, l'output te la nasconde — e il taccuino la custodisce *in
chiaro*: chi legge lo state legge ogni segreto. La seconda è il gioco delle
tre fonti di verità: codice, memoria, realtà — cancelli un container alle
spalle del modello e impari il comando che sincronizza *solo la memoria*
(plan e apply -refresh-only), separando "aggiornare il taccuino" da "toccare
il mondo". La terza è il finale che prepara il capitolo 12: un collega clona
il tuo codice ma non la tua memoria — il suo piano vuole ricostruire tutto,
il suo apply si schianta sulla realtà che già esiste, e il suo taccuino
resta a metà. Stesso codice, due memorie, una sola realtà: è il problema
che solo lo stato *condiviso* risolve.

## Obiettivi

Alla fine saprai:

- spiegare quale problema risolve lo stato: il legame indirizzo-nel-codice
  ↔ oggetto-reale che né il codice né la realtà contengono;
- orientarti dentro terraform.tfstate: version, serial, lineage, resources,
  attributes, dependencies;
- dimostrare che sensitive protegge l'*output*, non lo *state* — e trarne
  le conseguenze operative;
- usare plan/apply -refresh-only per riallineare la memoria senza toccare
  la realtà;
- raccontare con un esempio concreto perché due memorie sullo stesso mondo
  portano alla collisione.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md. jq comodo ma
  facoltativo (in alternativa grep).
- Docker in esecuzione. Nessuna porta richiesta.
- I capitoli 1–2 (drift, convergenza) e 10 (il ponte che ti ha portato qui).

## Consegna

### Fase 0 — Un piccolo mondo con un segreto

In start/main.tf trovi tre risorse: una random_password (il segreto del
database, marcato sensitive), l'immagine nginx e un container. Nessun TODO
di scrittura stavolta: il lavoro del capitolo è *leggere* — il taccuino, i
piani, gli errori.

    cd start
    tofu init
    tofu apply
    tofu output

L'output è già la prima lezione: db_password = <sensitive>. Riservatezza
apparente — tra un minuto la smontiamo.

### Fase 1 — Dentro al taccuino

Il file è lì, accanto al codice: terraform.tfstate. Aprilo:

    jq '.version, .serial, .lineage' terraform.tfstate
    jq '.resources[] | {type, name}' terraform.tfstate
    jq '.resources[] | select(.type=="docker_container") | .instances[0].attributes.id' terraform.tfstate

Orientati: version (il formato), serial (cresce a ogni scrittura), lineage
(l'identità di *questa* memoria, dalla nascita), e resources — la mappatura
che è la ragione d'essere di tutto: docker_container.web, indirizzo nel
codice, legato all'id reale del container. È il problema dell'11.1
risolto: il codice dice "un container chiamato web", la realtà ne contiene
mille — *solo il taccuino* sa quale è tuo. Cerca anche la voce
dependencies del container: il taccuino ricorda perfino gli archi del
grafo (serve al destroy per demolire in ordine inverso anche se un giorno
cancellassi il blocco dal codice).

### Fase 2 — Il segreto in chiaro

L'output diceva <sensitive>. Ora chiedi al taccuino:

    jq -r '.resources[] | select(.type=="random_password") | .instances[0].attributes.result' terraform.tfstate

Eccola, in chiaro. (Senza jq: grep result terraform.tfstate.) Nota il
paradosso raffinato: nello stesso file c'è sensitive_attributes che *marca*
result come sensibile — la marca serve a redigere gli output e i piani, ma
il valore deve stare nello state per forza: senza, lo strumento non
potrebbe confrontare né riusare quel valore. Conseguenze non negoziabili:
lo state non si committa mai (il .gitignore di questo repo lo esclude — e
ora sai perché), si protegge come un portachiavi (accessi ristretti,
cifratura at rest: i backend del capitolo 12), e OpenTofu ha un asso in
più — la cifratura nativa dello state — che è uno dei motivi del capitolo
20.

### Fase 3 — Le tre fonti di verità

Codice, memoria, realtà. Falle divergere: cancella il container alle
spalle del modello (il drift del capitolo 1, versione demolitiva):

    docker rm -f cap11-web
    tofu plan -refresh-only

Leggi bene il titolo: Objects have changed outside of OpenTofu —
docker_container.web has been deleted. Il -refresh-only è il piano *della
sola memoria*: confronta taccuino e realtà, ignora il codice, e non
propone di costruire niente — solo di prendere atto. Accetta:

    tofu apply -refresh-only
    tofu state list

Il container è sparito dalla memoria (le altre due risorse restano). Nota
che la realtà non è stata toccata: hai solo aggiornato il taccuino. Adesso
rimetti in gioco la terza fonte:

    tofu plan

1 to add: codice (lo vuole) contro memoria aggiornata (sa che non c'è).
Applica e il mondo torna intero. Il ciclo completo, esplicitato: refresh
allinea memoria↔realtà, plan confronta codice↔memoria, apply piega la
realtà al codice.

### Fase 4 — Il collega col taccuino vuoto

Un collega clona il tuo progetto. Il codice viaggia in git; lo state no
(Fase 2 docet). Simulalo:

    mkdir ../colleague
    cp main.tf ../colleague/
    cd ../colleague
    tofu init
    tofu plan

Plan: 3 to add. Rileggilo: il suo piano vuole creare *tutto* — password,
immagine, container. Non è impazzito: la sua memoria è vuota, e per lui i
tuoi oggetti semplicemente non esistono. Ora lascialo applicare:

    tofu apply

Errore: Conflict. The container name "/cap11-web" is already in use. La
realtà è una sola, e il tuo container la occupava. E guarda il suo
taccuino dopo lo schianto:

    tofu state list

password e immagine ci sono (create prima della collisione): memoria a
metà, mondo conteso, due "proprietari" dello stesso nome. Questo è il
problema dell'11.5 in miniatura: *lo stato separato non scala oltre una
persona*. La soluzione non è disciplina — è UN taccuino solo, condiviso,
con un lucchetto: i backend remoti, capitolo 12.

### Pulizia

Due taccuini, due destroy:

    tofu destroy          # nella cartella colleague
    cd ../start
    tofu destroy

## Criteri di "fatto"

- Sai indicare nel tfstate: serial, lineage, la mappatura
  docker_container.web → id reale, e la voce dependencies.
- Hai visto la stessa password <sensitive> nell'output e in chiaro nello
  state.
- Il plan -refresh-only ha mostrato "has been deleted" e l'apply
  -refresh-only ha aggiornato SOLO la memoria (state list senza container,
  realtà intatta).
- Il collega: piano "3 to add", apply fallito con Conflict, state list
  parziale (password e immagine).
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Il problema dell'11.1: il codice dice "un container chiamato web",
la realtà ne contiene tanti — che cosa sa il taccuino che né il codice né
la realtà contengono? E perché il taccuino registra anche le dependencies,
se il grafo si può ricostruire dal codice? (Pensa a un blocco cancellato
dal codice prima di un destroy.)

**b.** Il segreto: perché il valore della password DEVE stare nello state,
se sensitive lo nasconde altrove? Elenca le conseguenze operative (git,
accessi, cifratura) e spiega che cosa aggiunge il -refresh-only alla tua
cassetta degli attrezzi: in quali situazioni vuoi aggiornare la memoria
*senza* toccare il mondo?

**c.** Il collega: ricostruisci l'incidente con le tre fonti di verità
(che cosa diceva il suo codice, la sua memoria, la realtà) e spiega perché
nessuna disciplina di coordinamento via chat può sostituire un taccuino
condiviso. Che cosa dovrà garantire, come minimo, il "taccuino unico" del
capitolo 12 perché due colleghi possano lavorare senza pestarsi? (Pensa
anche a che cosa serve il lucchetto.)
