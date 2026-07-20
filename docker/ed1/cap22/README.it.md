# Capitolo 22 — La cassaforte, non il post-it

**Livello:** Avanzato

Un'applicazione non è solo servizi e reti: è anche configurazione. L'indirizzo del
database, il livello di log, la chiave dell'API — e, tra questi, cose che non devono
finire in chiaro da nessuna parte. Docker Compose offre tre strumenti che è facile
confondere. Le variabili d'ambiente configurano il comportamento del servizio. Il file
.env tiene i valori fuori dal compose e fuori dal repository. E i secrets sono la
cassaforte: dati sensibili montati nel container come file a permessi ristretti, non
scritti nell'ambiente dove chiunque ispezioni il container li vedrebbe. In questo
laboratorio configuri un servizio con una variabile presa da .env e gli dai una
password come secret — e verifichi che il segreto è nel file giusto e non trapela
nell'ambiente.

## Obiettivi

- Passare una variabile d'ambiente a un servizio (22.1).
- Prenderne il valore da un file .env, tenuto fuori dal repository (22.2).
- Dare un dato sensibile come secret, montato come file in /run/secrets (22.3).
- Vedere perché un secret non finisce nell'ambiente, a differenza di una env var
  (22.4).

## Prerequisiti

- Un Linux con Docker Engine attivo e il plugin Docker Compose (vedi SETUP.md). Il
  tuo utente deve poter usare Docker.
- Il capitolo 20-21 (Compose): qui aggiungi la configurazione e i segreti.

## Lo scenario

In start/ trovi compose.yaml: il servizio app non ha configurazione né secret. Colmi
tre lacune (TODO 1..3). Servono due file che **non si committano** (è il punto del
capitolo): creali prima di provare la tua soluzione —

    cd docker/ed1/cap22/start
    printf 'APP_ENV=production\n' > .env
    printf 's3cr3t-pw' > db_password.txt

Il progetto Compose ha un nome unico e viene rimosso alla fine; il demone non si
tocca. (solution/run.sh genera da sé questi due file in una cartella temporanea, così
il test non dipende da nulla di committato.)

### Fase 1 — La variabile da .env (22.1, 22.2 — TODO 1)

Apri start/compose.yaml e completa il **TODO 1**: dai ad app una variabile d'ambiente
il cui valore è preso dal file .env. Compose sostituisce ${APP_ENV} con quanto trova
in .env — che resta fuori dal repository.

    environment:
      APP_ENV: ${APP_ENV}

### Fase 2 — Definire il secret (22.3 — TODO 2)

Completa il **TODO 2**: definisci un secret a livello di progetto, da un file. È la
cassaforte: il valore vive in un file, non nel compose.

    secrets:
      db_password:
        file: ./db_password.txt

### Fase 3 — Dare il secret al servizio (22.3 — TODO 3)

Completa il **TODO 3**: assegna il secret al servizio. Compose lo monta dentro il
container come file in /run/secrets/db_password — non come variabile d'ambiente.

    secrets:
      - db_password

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- app riceve APP_ENV con valore preso da .env (TODO 1).
- Il secret db_password è definito da un file (TODO 2) e assegnato ad app (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh porta su l'applicazione e verifica, punto per punto:

- **OK 1** — la variabile d'ambiente APP_ENV nel container ha il valore preso da
  .env (production).
- **OK 2** — il secret è montato come file in /run/secrets/db_password e contiene il
  valore atteso.
- **OK 3** — il secret NON trapela nell'ambiente: il suo valore non compare tra le
  variabili d'ambiente del container.

## Domande di riflessione

**a.** environment e .env sembrano la stessa cosa ma non lo sono: environment mette le
variabili dentro il servizio, .env fornisce i valori per la sostituzione ${...} e sta
fuori dal compose. Perché il file .env va in .gitignore, e perché tenere i valori
separati dal file di configurazione è utile anche per i valori non segreti (ambienti
diversi, stessa app)?

**b.** Perché per un dato sensibile un secret è meglio di una variabile d'ambiente?
Pensa a dove finisce una env var — visibile in docker inspect, in docker ps, ereditata
dai processi figli, spesso stampata nei log — contro un secret, montato come file a
permessi ristretti in /run/secrets (su un tmpfs, non su disco) e assente
dall'ambiente. Cosa cambia per chi riesce a ispezionare il container?

**c.** I secrets di Compose sono file-based, un primo passo. In produzione i valori
vengono da un gestore di segreti (Vault, i secret del cloud) invece che da un file sul
disco. In che modo l'idea — montare il segreto come file, mai metterlo nell'ambiente —
è la stessa dei Secret di Kubernetes, e perché questo modello è più sicuro di
incollare la chiave in una variabile?

## Pulizia

Niente da smontare a mano: run.sh chiude il progetto con docker compose down e rimuove
la cartella temporanea (con .env e file segreto generati), tramite un trap. Se hai
creato .env e db_password.txt in start/ per provare la tua soluzione, ricordati di
cancellarli. L'immagine base busybox resta in cache. Il demone non viene mai riavviato.

## Dove porta

Con questo capitolo la Parte 6 è completa: sai progettare, ordinare e configurare
un'applicazione multi-servizio. La **Parte 7** cambia tema — day-2, sicurezza,
hardening. Il **capitolo 23** apre con il modello dei privilegi e la modalità rootless:
far girare l'intero motore senza root, riprendendo lo USER namespace del capitolo 2.
Per il riferimento di Compose, vedi le appendici del volume.
