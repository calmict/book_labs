# Capitolo 9 — Il piano di carico

**Livello:** Fondamentale

Nel capitolo 8 hai smontato un'immagine nei suoi strati; ora la costruisci tu, con
intenzione. Il Dockerfile è il piano di carico della nave: un elenco ordinato di
istruzioni che dicono da quale scafo partire, cosa imbarcare, dove metterlo e quale
comando eseguire alla partenza. In questo laboratorio completi un Dockerfile con le
istruzioni fondamentali — COPY, ENV, CMD — e verifichi che l'immagine costruita si
comporti esattamente come l'hai dichiarata: il file al posto giusto, la variabile
impostata, il comando di default che parte da solo.

## Obiettivi

- Partire da un'immagine base con FROM e fissare la directory di lavoro con
  WORKDIR (9.1, 9.4).
- Portare un file dal contesto di build dentro l'immagine con COPY (9.3).
- Impostare una variabile d'ambiente con ENV, che l'applicazione legge a runtime
  (9.4).
- Dichiarare il comando di default con CMD, e vedere che parte quando avvii il
  container senza argomenti (9.5).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter
  usare Docker.
- Il capitolo 8: sai che ogni istruzione che tocca il filesystem diventa un layer.
  Qui scrivi quelle istruzioni.

## Lo scenario

In start/ trovi un Dockerfile incompleto e greet.sh, una piccola app che stampa un
saluto letto da una variabile d'ambiente. Il Dockerfile parte da busybox, fissa
WORKDIR /app e crea un file con RUN, ma non imbarca l'app, non imposta il saluto e
non ha un comando di default. Colmi tre lacune (TODO 1..3) perché l'immagine sia
completa. Immagine usa-e-getta, nessun privilegio, il demone condiviso non si
tocca.

Prepara l'ambiente:

    cd docker/ed1/cap09/start

### Fase 1 — Base, contesto e strati (9.1, 9.2)

Il Dockerfile parte da FROM busybox (lo scafo), fissa WORKDIR /app (dove lavorare)
ed esegue una RUN al momento della build. Ogni istruzione che cambia il filesystem
aggiunge uno strato: è la stessa pila che hai contato nel capitolo 8. Attenzione:
docker build invia al demone tutto il contenuto della cartella (il contesto di
build), non solo il Dockerfile.

### Fase 2 — Imbarcare l'app con COPY (9.3 — TODO 1)

Apri start/Dockerfile e completa il **TODO 1**: copia greet.sh dal contesto di
build dentro la WORKDIR dell'immagine.

    COPY greet.sh /app/greet.sh

### Fase 3 — Il saluto come variabile d'ambiente (9.4 — TODO 2)

Completa il **TODO 2**: imposta la variabile GREETING, che greet.sh legge a
runtime. ENV la scrive nella config dell'immagine, quindi vale per ogni container
che ne nasce.

    ENV GREETING=ciao

### Fase 4 — Il comando di default con CMD (9.5 — TODO 3)

Completa il **TODO 3**: dichiara il comando di default, così avviando il container
senza argomenti parte l'app. A differenza di RUN (che esegue in fase di build),
CMD non esegue nulla ora: è solo metadato, il comando che partirà a runtime.

    CMD ["sh", "/app/greet.sh"]

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- Il Dockerfile copia greet.sh nella WORKDIR (TODO 1).
- Imposta la variabile d'ambiente GREETING (TODO 2).
- Dichiara il comando di default con CMD (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh costruisce l'immagine e verifica, punto per punto:

- **OK 1** — COPY e WORKDIR: greet.sh è nell'immagine in /app e la WorkingDir
  della config è /app.
- **OK 2** — ENV: la config dell'immagine contiene GREETING=ciao.
- **OK 3** — CMD: avviando il container senza argomenti, il comando di default
  esegue greet.sh e stampa «ciao mondo», usando la variabile impostata.

## Domande di riflessione

**a.** L'ordine delle istruzioni non è indifferente: perché conviene mettere ciò
che cambia raramente (la base, le dipendenze) prima di ciò che cambia spesso (il
codice dell'app)? Collega la risposta ai layer del capitolo 8 e alla cache di
build del capitolo 11.

**b.** RUN e CMD sembrano simili ma vivono in tempi diversi: RUN esegue durante la
build e cristallizza il risultato in un layer; CMD non esegue nulla in build, è il
comando che partirà a runtime. Perché questa differenza è la ragione per cui CMD
non crea un layer e può essere sovrascritto all'avvio?

**c.** docker build invia al demone l'intero contesto di build. Cosa comporta un
contesto grande o con file sensibili, e a cosa serve un .dockerignore? E perché
WORKDIR è preferibile a un «cd» dentro una RUN?

## Pulizia

Niente da smontare a mano: l'immagine di prova è rimossa dallo script (docker rmi,
più un trap di sicurezza) a fine esecuzione; il test lavora nel proprio contesto e
non lascia container. L'immagine base busybox resta in cache (condivisa). Il
demone non viene mai riavviato.

## Dove porta

Hai dichiarato un comando di default con CMD. Il **capitolo 10** apre proprio
questo nodo: la differenza tra ENTRYPOINT e CMD e il processo di avvio del
container — chi è davvero PID 1, e come argomenti e comando si combinano. Per il
riferimento completo delle istruzioni Dockerfile, vedi le appendici del volume.
