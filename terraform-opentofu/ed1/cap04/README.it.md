# Capitolo 4 — Il capocantiere invisibile

**Livello:** Fondamentale
**Tempo stimato:** 35–45 minuti
**Argomenti del manuale:** che cos'è un grafo orientato aciclico (4.1), come Terraform costruisce il grafo (4.2), dipendenze implicite ed esplicite (4.3), la parallelizzazione (4.4), visualizzare il grafo con terraform graph (4.5), il ciclo proibito: «Cycle detected» (4.6), cosa portiamo a casa dalla Parte 1 (4.7)

## L'idea

Nei tre capitoli scorsi una domanda è rimasta aperta: quando le risorse sono
tante e collegate, chi decide *in che ordine* costruirle? Non tu — non hai
mai scritto un ordine da nessuna parte. Lo decide un capocantiere invisibile:
il grafo delle dipendenze, che lo strumento costruisce leggendo il tuo
codice.

In questo esercizio lo rendi visibile con lo strumento più onesto che c'è: il
cronometro. Costruisci tre piani da 5 secondi l'uno *senza dirgli che sono
una torre*: salgono tutti insieme, 5 secondi totali — fisicamente assurdo, ma
il modello non sa che un piano poggia sull'altro finché il codice non glielo
dice. Poi incateni i piani coi riferimenti e riguardi il cronometro: 15
secondi, uno alla volta. Stesse tre risorse, nessun "ordine" scritto: solo
archi nati dai riferimenti. Infine guardi il grafo in faccia con tofu graph,
osservi la demolizione procedere all'incontrario, e provi a costruire l'unica
cosa che il capocantiere rifiuta: il ciclo — la gallina che nasce dall'uovo
che è deposto dalla gallina.

## Obiettivi

Alla fine saprai:

- spiegare da dove nascono gli archi del grafo: il riferimento è l'arco
  (dipendenza implicita), depends_on è l'arco dichiarato a mano (esplicita);
- misurare la parallelizzazione: perché ciò che non è collegato viaggia
  insieme, e ciò che è collegato aspetta;
- leggere l'output di tofu graph e trovare i tuoi archi;
- prevedere l'ordine di demolizione: lo stesso grafo, percorso al contrario;
- riconoscere il ciclo proibito e spiegare perché viene rifiutato *prima* di
  toccare la realtà.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md. I comandi usano tofu;
  con terraform sono identici.
- Nessun Docker stavolta: bastano i provider time e local (li scarica init).

## Consegna

### Fase 0 — La torre che galleggia

Apri start/main.tf: tre piani, ognuno con un tempo di costruzione di 5
secondi (una risorsa time_sleep: il "lavoro" è dormire, il che la rende
perfetta per cronometrare il cantiere). Nota che nessun piano nomina gli
altri. Applica misurando il tempo:

    cd start
    tofu init
    time tofu apply -auto-approve

Guarda il tempo reale: circa 5 secondi, non 15. I tre piani sono saliti
*insieme* — una torre i cui piani si costruiscono in parallelo è un assurdo
fisico, ma il modello non contiene da nessuna parte l'informazione che
floor_2 poggia su floor_1. Niente archi, niente attese: il capocantiere ha
mandato tre squadre in parallelo, com'era giusto fare *dato il grafo che
aveva*.

### Fase 1 — Incatenare i piani (dipendenze implicite)

Il TODO 1 ti chiede di dire al modello ciò che la fisica sa già: ogni piano
poggia sul precedente. Non scriverai "prima... poi...": inserirai nei
triggers di floor_2 un *riferimento* a floor_1 (e in floor_3 uno a floor_2).
Il riferimento è tutto: dove un valore fluisce da una risorsa all'altra, lì
il grafo ha un arco.

Poi demolisci e ricostruisci, cronometro alla mano:

    tofu destroy -auto-approve
    time tofu apply -auto-approve

Ora circa 15 secondi: un piano alla volta. Stesse tre risorse, stesso codice
a parte due righe di riferimento — ma il grafo è cambiato, e con lui
l'ordine. L'apply te lo ha anche raccontato in diretta: guarda nell'output
la sequenza delle righe Creating/Creation complete.

### Fase 2 — L'agibilità (dipendenza esplicita)

Il TODO 2 aggiunge il certificato di agibilità: un file che deve nascere
solo a torre finita. Ma il suo contenuto non usa *nessun* attributo dei
piani: non c'è un valore che fluisce, quindi nessun riferimento — e senza
riferimento, nessun arco. È il caso (raro) in cui l'arco lo dichiari a mano:

    depends_on = [time_sleep.floor_3]

Applica e osserva che il certificato compare per ultimo. Regola pratica: il
riferimento quando un valore serve davvero, depends_on solo quando la
dipendenza è reale ma invisibile ai dati.

### Fase 3 — Guardare il grafo in faccia

Finora il grafo l'hai dedotto dal cronometro. Ora guardalo:

    tofu graph | grep ' -> '

In mezzo agli archi di servizio (provider, root) trovi i tuoi:
floor_2 -> floor_1, floor_3 -> floor_2, certificate -> floor_3. Leggi la
freccia come "dipende da": punta sempre verso ciò che deve esistere prima.
(Se hai graphviz, prova: tofu graph | dot -Tsvg > graph.svg — ma non serve
per l'esercizio.)

### Fase 4 — La demolizione, all'incontrario

    tofu destroy

Prima di confermare, osserva il piano; poi, mentre demolisce, guarda l'ordine
delle righe Destroying: floor_3 per primo, floor_1 per ultimo, il certificato
prima di tutti. È lo stesso grafo, percorso al contrario — nessuno demolisce
il piano terra con il terzo piano ancora sopra. È il motivo per cui nel
capitolo 3 l'immagine è stata creata prima del container, ma distrutta dopo.

### Fase 5 — Il ciclo proibito

In start/cycle/ trovi un modello completo ma rotto per costruzione: la
gallina nasce dall'uovo, l'uovo è deposto dalla gallina. Ognuno referenzia
l'altro: due archi che si mordono la coda.

    cd cycle
    tofu init
    tofu validate

Errore: Cycle: local_file.chicken, local_file.egg. Fermati su due dettagli.
Primo, il *perché*: il capocantiere deve trovare qualcuno che possa partire
per primo, e in un ciclo non esiste — ogni nodo aspetta un altro nodo del
ciclo. Per questo il grafo dev'essere aciclico: non è pignoleria, è
l'esistenza stessa di un ordine di esecuzione. Secondo, il *quando*: te lo
ha detto validate, senza toccare nulla — il grafo si costruisce dal codice,
quindi il difetto si scopre prima di qualsiasi contatto con la realtà.

### Pulizia

Torna in start/ (il ciclo non ha mai creato nulla) e, se non l'hai già fatto:

    tofu destroy

## Criteri di "fatto"

- L'apply della Fase 0 è durato circa 5 secondi; quello della Fase 1 circa
  15 (li hai misurati con time).
- In tofu graph hai individuato i tre archi tuoi: floor_2 -> floor_1,
  floor_3 -> floor_2, certificate -> floor_3.
- Nella demolizione l'ordine era inverso: certificato e floor_3 prima,
  floor_1 ultimo.
- tofu validate in cycle/ fallisce con Error: Cycle e i nomi delle due
  risorse.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Da dove sono nati, uno per uno, gli archi del tuo grafo? Non hai mai
scritto "prima questo, poi quello": che cosa li ha creati al posto tuo, e in
che direzione puntano le frecce di tofu graph? E quando è giusto ricorrere a
depends_on invece che a un riferimento?

**b.** Il cronometro: 5 secondi contro 15, con le stesse tre risorse da 5
secondi l'una. Spiega entrambe le misure in termini di grafo. Poi il ciclo:
perché un grafo con un ciclo non ammette *nessun* ordine di esecuzione, e che
cosa ti dice il fatto che l'errore arrivi da validate, prima di toccare la
realtà?

**c.** Il filo completo della Parte 1: il drift (cap. 1), la convergenza
(cap. 2), l'immutabilità (cap. 3), il grafo (cap. 4). Componi il quadro in
poche righe: che viaggio fa il tuo main.tf dal momento in cui descrivi il
risultato al momento in cui la realtà gli somiglia? E perché la demolizione
in ordine inverso non è una cortesia ma una necessità (ripensa a immagine e
container del cap. 3)?
