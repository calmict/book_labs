# Capitolo 16 — Il banco di prova

**Livello:** Intermedio
**Tempo stimato:** 45–55 minuti
**Argomenti del manuale:** che cos'è una funzione in HCL (16.1), le famiglie di funzioni (16.2), esempi che incontrerai davvero (16.3), le espressioni for: trasformare collezioni (16.4), terraform console: il banco di prova (16.5)

## L'idea

Il capitolo scorso si chiudeva con una promessa: le collezioni che dai a count e
for_each vanno spesso *preparate* prima — pulite, trasformate, filtrate. Questo
capitolo ti dà gli attrezzi per prepararle, e un banco su cui provarli prima di
montarli.

Gli attrezzi sono le **funzioni**: HCL ne ha un centinaio, già pronte (non puoi
scriverne di tue nel modo classico — prendi quelle che ci sono). Trasformano una
stringa (lower, trimspace, split), contano e combinano collezioni (length,
merge, keys), le convertono (toset, tolist, jsonencode). Una funzione prende
input tra parentesi e restituisce un valore: nient'altro, nessun effetto
collaterale.

Il banco è **tofu console**: una REPL dove digiti un'espressione e vedi subito
il risultato, *senza toccare nulla* — niente plan, niente apply, niente stato. È
il posto dove provi lower(trimspace(" Web-01 ")) e leggi "web-01" prima di
fidarti a scriverlo nel codice.

E la catena di montaggio è l'**espressione for**: non il meta-argomento del
capitolo 15, ma un'espressione che prende una collezione e ne sputa un'altra,
trasformata. [for h in lista : pulisci(h)] rifà la lista pulita;
{ for h in lista : h => ruolo(h) } ne costruisce una mappa; e un if in coda
*filtra*. Partirai da una lista di host scritta male — spazi, maiuscole a caso,
un doppione — e la farai diventare l'insieme ordinato e pulito che poi guida
davvero i tuoi container.

## Obiettivi

Alla fine saprai:

- dire che cos'è una funzione HCL e riconoscere le famiglie principali (stringa,
  collezione, conversione, codifica);
- usare tofu console per provare un'espressione senza toccare stato né
  infrastruttura;
- trasformare una lista con un'espressione for (list comprehension) e ripulirla
  con le funzioni;
- costruire una *mappa* con un'espressione for (map comprehension), e *filtrarla*
  con un if;
- collegare la collezione trasformata a un for_each (l'eredità del capitolo 15) e
  vedere il dedup all'opera.

## Prerequisiti

- OpenTofu (o Terraform) installato — vedi SETUP.md.
- Docker in esecuzione. Nessuna porta host pubblicata.
- Il capitolo 15 (for_each, toset): qui prepari le collezioni che gli dai in
  pasto.

## Consegna

### Fase 0 — Il banco (tofu console)

Prima di scrivere qualsiasi cosa, sali sul banco. Da start/:

    cd start
    tofu init
    tofu console

Sei nella REPL. Prova gli attrezzi — ogni riga restituisce un valore, niente
viene toccato:

    lower(trimspace("  Web-01 "))
    length(["a", "b", "c"])
    merge({ team = "web" }, { tier = "1" })
    split("-", "web-01")
    split("-", "web-01")[0]

Leggi le risposte: "web-01", 3, la mappa unita, la lista ["web","01"], "web".
Sono le famiglie che userai: stringa (lower, trimspace, split), collezione
(length, merge), accesso ([0]). Esci dal banco con exit (o Ctrl-D). Regola d'oro
del capitolo: **ogni espressione che non sei sicuro di come si comporti, provala
qui prima di metterla nel codice.**

### Fase 1 — La catena di montaggio (TODO 1: list comprehension)

Apri start/main.tf: la variabile raw_hosts è una lista scritta *male* —
"  Web-01 ", "API-02", "web-01", "DB-03 ": spazi ai lati, maiuscole incoerenti,
e Web-01/web-01 che sono lo stesso host scritto in due modi. Il TODO 1 ti chiede
di ripulirla con un'espressione for. Prima **provala sul banco**:

    tofu console
    [for h in var.raw_hosts : lower(trimspace(h))]

Vedi la lista normalizzata — ma con web-01 *due volte*. Avvolgila in toset() per
deduplicare e ottenere identità:

    toset([for h in var.raw_hosts : lower(trimspace(h))])

Esci, e scrivi il risultato nel local clean_hosts (sostituendo il segnaposto
toset([])):

    clean_hosts = toset([for h in var.raw_hosts : lower(trimspace(h))])

Questo local guida già un for_each di container (in fondo al file, l'eredità del
capitolo 15). Applica:

    tofu apply
    tofu state list

Quattro host grezzi, ma **tre** container: docker_container.host["api-02"],
["db-03"], ["web-01"]. Il doppione è sparito nel toset. La collezione preparata a
mano è diventata infrastruttura.

### Fase 2 — La mappa derivata (TODO 2: map comprehension)

Un'espressione for può costruire una *mappa*, non solo una lista: cambia la
sintassi da : a =>. Il TODO 2 costruisce host_roles, che associa a ogni host il
suo *ruolo* — il prefisso prima del trattino. Provala:

    tofu console
    { for h in local.clean_hosts : h => split("-", h)[0] }

Leggi { "api-02" = "api", "db-03" = "db", "web-01" = "web" }. Scrivila nel local
host_roles (sostituendo {}), poi guardala come output:

    tofu apply
    tofu output host_roles

### Fase 3 — Il filtro (TODO 3: comprehension con if)

Un if in coda all'espressione for *filtra*: tiene solo gli elementi che passano
la condizione. Il TODO 3 costruisce web_hosts, solo gli host il cui ruolo è
"web". Provala:

    tofu console
    toset([for h in local.clean_hosts : h if split("-", h)[0] == "web"])

Leggi toset(["web-01"]): solo lui passa. Scrivila nel local web_hosts
(sostituendo toset([])), poi:

    tofu apply
    tofu output web_hosts

### Fase 4 — Le funzioni che producono un file

Guarda in fondo al file il local_file inventory (già scritto, non è un TODO): il
suo contenuto è jsonencode di una struttura che usa sort, tolist e le tue tre
collezioni. È l'altro volto delle funzioni — non solo provate sul banco, ma che
producono un artefatto reale:

    cat inventory.json

Un JSON ordinato con hosts, roles e web: le tue trasformazioni, serializzate.
jsonencode/sort/tolist sono le famiglie *codifica* e *conversione* al lavoro.

### Fase 5 — Il ponte (si riflette)

Hai preso materiale grezzo e l'hai lavorato sul banco fino a farne
infrastruttura: funzioni per pulire, espressioni for per rimodellare, console
per provare senza rischi. Finora però hai *ripetuto* lo stesso schema (variabili,
risorse, output) in ogni cartella. La Parte 5 lo impacchetta una volta per
tutte: il capitolo 17, i moduli, prende questo blocco e lo rende riusabile con un
nome e delle porte — le variabili e gli output che già conosci, ma come
*interfaccia* di una scatola.

### Pulizia

    tofu destroy

## Criteri di "fatto"

- Sul banco (console): lower(trimspace("  Web-01 ")) dava "web-01" e
  split("-", "web-01")[0] dava "web".
- Dopo il TODO 1, da 4 host grezzi nascevano 3 container (dedup nel toset): gli
  indirizzi erano host["api-02"], ["db-03"], ["web-01"].
- host_roles (TODO 2) associava web-01=web, api-02=api, db-03=db.
- web_hosts (TODO 3) conteneva solo web-01.
- inventory.json conteneva il JSON con hosts, roles e web.
- Hai risposto alle tre domande in answers.md.

## Le tre domande

**a.** Il banco: che cos'è una funzione HCL (input, output, effetti collaterali)
e perché tofu console è sicuro da usare anche su un progetto reale in
produzione? Cita tre funzioni che hai provato e la famiglia di ciascuna.

**b.** La catena di montaggio: spiega la differenza tra l'espressione for come
*list comprehension* ([… : …]) e come *map comprehension* ({… : … => …}), e che
cosa fa l'if in coda. Nel TODO 1, che ruolo ha esattamente toset() rispetto alla
sola espressione for — e perché 4 host grezzi hanno prodotto 3 container?

**c.** Prova prima, monta poi: perché conviene provare un'espressione in console
*prima* di scriverla nel codice, invece di scriverla e fare apply per vedere se
funziona? Collega la risposta al ciclo plan/apply del capitolo 6 — che cosa ti
fa risparmiare il banco, e in che cosa è diverso da un plan?
