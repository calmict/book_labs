# Capitolo 20 — La flotta in un foglio

**Livello:** Intermedio

Finora hai comandato una nave alla volta: docker run, docker network, docker volume,
un pezzo per volta. Ma un'applicazione vera è una flotta — un web, un database, una
cache — e coordinarla a mano, comando su comando, è fragile e irripetibile. La Parte
6 introduce lo strumento che descrive l'intera flotta in un foglio solo: Docker
Compose. In un file dichiari i servizi, e Compose fa il resto — crea per te una rete
d'applicazione dove i servizi si trovano per nome (come il bridge custom del capitolo
17, ma senza scriverlo), rispetta le dipendenze, e avvia o ferma tutto con un comando.
In questo laboratorio progetti un'app a due servizi e verifichi che si parlano per
nome e che partono nell'ordine giusto.

## Obiettivi

- Descrivere un'applicazione multi-servizio in un unico file Compose (20.1).
- Definire due servizi con immagine e comando (20.2).
- Dichiarare una dipendenza tra servizi con depends_on (20.3).
- Vedere che Compose dà ai servizi una rete d'app dove si risolvono per nome (20.4).

## Prerequisiti

- Un Linux con Docker Engine attivo e il plugin Docker Compose (vedi SETUP.md). Il
  tuo utente deve poter usare Docker.
- Il capitolo 17 (rete custom, risoluzione per nome): Compose la crea per te. Il
  capitolo 13-14 (volumi): li comporrai nei prossimi capitoli.

## Lo scenario

In start/ trovi compose.yaml: descrive due servizi, db e web, ma senza un comando che
li tenga in vita e senza la dipendenza — così l'app non sta su. Colmi tre lacune
(TODO 1..3). Il progetto Compose ha un nome unico e viene rimosso alla fine (down);
il demone non si tocca e non si riavvia.

Prepara l'ambiente:

    cd docker/ed1/cap20/start

### Fase 1 — Tenere in vita i servizi (20.2 — TODO 1, TODO 2)

Apri start/compose.yaml. Un servizio con la sola immagine avvia il comando di default
(per busybox, una shell che esce subito): il container non resta su. Completa il
**TODO 1** e il **TODO 2**: dai a db e a web un comando che li tenga in vita.

    command: sleep 3600

### Fase 2 — L'ordine di avvio (20.3 — TODO 3)

Completa il **TODO 3**: fai partire web dopo db, dichiarando la dipendenza. Compose
avvierà db per primo.

    depends_on:
      - db

### Fase 3 — La rete d'app (20.4)

Non c'è nulla da scrivere: Compose crea automaticamente una rete per il progetto e ci
mette entrambi i servizi. Lì il DNS integrato risolve i nomi dei servizi, quindi web
raggiunge db semplicemente come «db» — mai per IP.

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- compose.yaml definisce db e web con un comando che li tiene in vita (TODO 1, 2).
- Dichiara che web dipende da db (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh porta su l'applicazione e verifica, punto per punto:

- **OK 1** — entrambi i servizi (db e web) sono in esecuzione dopo docker compose up.
- **OK 2** — web raggiunge db per nome di servizio: la rete d'app creata da Compose ha
  il DNS integrato.
- **OK 3** — il file dichiara che web dipende da db (grafo delle dipendenze), da un
  solo file dichiarativo.

## Domande di riflessione

**a.** Compose crea automaticamente una rete per il progetto e ci attacca tutti i
servizi, con la risoluzione per nome vista nel capitolo 17. Perché in un file Compose
non usi mai gli indirizzi IP, ma sempre i nomi dei servizi? Cosa succederebbe se due
progetti Compose diversi avessero entrambi un servizio «db»?

**b.** depends_on ordina l'avvio — db prima di web — ma di default aspetta solo che il
container di db sia partito, non che il database dentro sia pronto ad accettare
connessioni. Perché questa distinzione conta, e cosa serve in più per aspettare la
vera prontezza (l'anticipo del capitolo 21: healthcheck)?

**c.** Un solo file descrive l'intera applicazione, e un solo comando la avvia o la
ferma. Perché questo modello dichiarativo — «ecco come deve essere», non «esegui
questi comandi in quest'ordine» — è il ponte concettuale verso Kubernetes, dove
dichiari lo stato desiderato e l'orchestratore lo realizza?

## Pulizia

Niente da smontare a mano: run.sh chiude il progetto con docker compose down (rimuove
container e rete d'app del progetto), con un trap di sicurezza. L'immagine base
busybox resta in cache. Il demone non viene mai riavviato.

## Dove porta

Hai descritto un'applicazione in un foglio e l'hai fatta partire con un comando. Ma
«partito» non è «pronto»: il **capitolo 21** affronta le dipendenze reali — depends_on
con condizione, gli healthcheck che dicono quando un servizio è davvero pronto, e
l'ordine di avvio che ne consegue. Per il riferimento di Compose, vedi le appendici
del volume.
