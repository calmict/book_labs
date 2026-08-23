# Capitolo 20 — La flotta in un foglio

**Livello:** Intermedio

Finora hai comandato una nave alla volta: docker run, docker network, docker volume,
un pezzo per volta. Ma un'applicazione vera è una flotta — un web, un database, una
cache — e coordinarla a mano, comando su comando, è fragile e irripetibile. La Parte
6 introduce lo strumento che descrive l'intera flotta in un foglio solo: Docker
Compose. In un file dichiari i servizi, e Compose fa il resto — crea per te una rete
d'applicazione dove i servizi si trovano per nome (come il bridge custom del capitolo
17, ma senza scriverlo), rispetta le dipendenze, e avvia o ferma tutto con un comando.
In questo laboratorio traduci tre docker run in un file solo: tre servizi che si
parlano per nome su una rete dichiarata, con un volume nominato per lo stato, un
quarto servizio che resta fuori dall'avvio perché appartiene a un profilo, e un file
di override che cambia il solo web quando lo passi.

## Obiettivi

- Descrivere un'applicazione multi-servizio in un unico file Compose (20.1).
- Definire i servizi con immagine e comando (20.2).
- Dichiarare una dipendenza tra servizi con depends_on (20.3).
- Vedere che i servizi si risolvono per nome sulla rete dell'applicazione (20.3).
- Tradurre tre docker run in un file: tre servizi, una rete dichiarata e un volume
  nominato al posto di tre comandi separati (20.3).
- Tenere un servizio fuori dall'avvio di default con profiles, e farlo partire solo
  quando serve (20.4).
- Sovrapporre al file base un compose.override.yaml di sviluppo, e vedere che
  cambia solo ciò che dichiara (20.4).

## Prerequisiti

- Un Linux con Docker Engine attivo e il plugin Docker Compose (vedi SETUP.md). Il
  tuo utente deve poter usare Docker.
- Il capitolo 17 (rete custom, risoluzione per nome): Compose la crea per te. Il
  capitolo 13-14 (volumi): li comporrai nei prossimi capitoli.

## Lo scenario

In start/ trovi compose.yaml: descrive db e web, ma senza un comando che li tenga in
vita, senza la dipendenza, senza rete né volume, senza il terzo servizio e senza
quello a profilo — così l'app non sta su e metà del file manca. Colmi sei lacune
(TODO 1..6).

Accanto trovi compose.override.yaml, già completo: non è un'applicazione a parte, è
lo strato che Compose fonde sul file base quando glieli passi entrambi. Il progetto
Compose ha un nome unico e viene rimosso alla fine (down, profili compresi); il
demone non si tocca e non si riavvia.

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

### Fase 3 — La rete e lo stato, dichiarati (20.3 — TODO 4)

Completa il **TODO 4**: dichiara la rete dell'applicazione e il volume nominato, e
mettici sopra i servizi. Compose una rete la crea comunque, anche se non la scrivi:
la differenza è che dichiarandola dici tu come si chiama e chi ci sta sopra, invece
di ereditare un default. Il volume nominato è lo stato di db, e sopravvive al
container (capitolo 13).

    networks:
      - appnet
    volumes:
      - dbdata:/var/lib/db

e, in fondo al file, le due dichiarazioni a cui i servizi si riferiscono:

    networks:
      appnet:

    volumes:
      dbdata:

Sulla rete il DNS integrato risolve i nomi dei servizi, quindi web raggiunge db
semplicemente come «db» — mai per IP.

### Fase 4 — Il terzo servizio (20.3 — TODO 5)

Completa il **TODO 5**: aggiungi cache, la terza nave della flotta. È il punto del
capitolo: tre docker run separati, con le loro rete e i loro nomi da ricordare,
diventano tre blocchi dentro lo stesso foglio.

    cache:
      image: busybox
      command: sleep 3600
      networks:
        - appnet

### Fase 5 — Il servizio che non parte (20.4 — TODO 6)

Completa il **TODO 6**: dichiara tools dentro un profilo. Un servizio con profiles
esiste nel file ma resta fuori da docker compose up: parte solo se lo chiedi
esplicitamente, con --profile tools. È il modo di tenere nello stesso foglio anche
ciò che serve raramente — un servizio di debug, un job di manutenzione — senza
farselo avviare ogni volta.

    tools:
      image: busybox
      command: sleep 3600
      networks:
        - appnet
      profiles:
        - tools

### Fase 6 — Lo strato di sviluppo (20.4)

Qui non c'è nulla da scrivere: compose.override.yaml è già pronto. Contiene solo
quello che cambia sulla tua macchina — una variabile per web — e non ripete il resto.
Compose lo fonde sul file base servizio per servizio, ma solo se glielo passi:

    docker compose -f compose.yaml -f compose.override.yaml up -d web

Il test lo verifica nei due modi: con il solo file base la variabile non c'è, con
l'override sopra c'è. È così che si tiene un solo modello di applicazione con più
ambienti, invece di due file che divergono.

Quando i sei TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- compose.yaml definisce db e web con un comando che li tiene in vita (TODO 1, 2).
- Dichiara che web dipende da db (TODO 3).
- Dichiara la rete dell'applicazione e il volume nominato, e ci mette i servizi
  (TODO 4).
- Aggiunge il terzo servizio, cache (TODO 5).
- Dichiara tools dentro un profilo, perché non parta di default (TODO 6).
- run.sh stampa OK 1..6 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh porta su l'applicazione e verifica, punto per punto:

- **OK 1** — i tre servizi (db, web, cache) sono in esecuzione dopo docker compose
  up; il quarto, a profilo, no.
- **OK 2** — web raggiunge db per nome di servizio: la rete dell'applicazione ha il
  DNS integrato.
- **OK 3** — il file dichiara che web dipende da db (grafo delle dipendenze), da un
  solo file dichiarativo.
- **OK 4** — esiste una sola rete di progetto e tutti e tre i servizi ci stanno
  sopra; esiste il volume nominato, ed è montato da db in /var/lib/db.
- **OK 5** — profiles: tools resta fuori dall'avvio di default, e parte solo quando
  lo si chiede con --profile tools.
- **OK 6** — override: con il solo compose.yaml la variabile MODE non esiste; con il
  file di override fuso sopra vale development. Cambia solo ciò che l'override
  dichiara.

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

Niente da smontare a mano: run.sh chiude il progetto con docker compose down -v,
profili compresi — rimuove i container, la rete e il volume nominato del progetto —
con un trap di sicurezza. Il volume è del progetto di prova, non un volume tuo. L'immagine base
busybox resta in cache. Il demone non viene mai riavviato.

## Dove porta

Hai descritto un'applicazione in un foglio e l'hai fatta partire con un comando. Ma
«partito» non è «pronto»: il **capitolo 21** affronta le dipendenze reali — depends_on
con condizione, gli healthcheck che dicono quando un servizio è davvero pronto, e
l'ordine di avvio che ne consegue. Per il riferimento di Compose, vedi le appendici
del volume.
