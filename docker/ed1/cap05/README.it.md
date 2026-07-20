# Capitolo 5 — La catena e il custode

**Livello:** Intermedio

Nella Parte 1 hai azionato a mano namespace, cgroup e overlay. Ora apri il cofano dello strumento che li
aziona per te — e la prima sorpresa è che «Docker» non è un programma solo, ma una catena di componenti
che si passano il lavoro. In questo laboratorio segui una richiesta dal socket fino al kernel: parli al
demone a mani nude, mappi la catena, e dimostri che il genitore del container è lo shim, non il demone.
È la prova tecnica dietro una promessa importante — puoi aggiornare Docker senza uccidere i tuoi
container.

## Obiettivi

- Parlare al demone direttamente sul socket con curl: la CLI è solo un client API (5.2).
- Verificare che la stessa API elenca i container, come farebbe docker ps (5.1, 5.2).
- Mappare la catena e provare che il genitore del container è un containerd-shim, non dockerd (5.3, 5.5).
- Capire perché sopra lo shim c'è systemd/containerd e non il demone: la base del live-restore (5.4).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md) e curl. Il tuo utente deve poter usare Docker (nel
  gruppo docker) — ma ricorda il capitolo 23: quel permesso equivale a root.
- La Parte 1 come fondamenta: qui vedrai runc azionare in automatico proprio i namespace, i cgroup e
  l'overlay che hai montato a mano.

## Lo scenario

In start/ trovi lacatena.sh: uno script che dovrebbe seguire una richiesta dall'API alla catena, ma non
registra ancora le informazioni che contano. Colmi tre lacune (TODO 1..3) usando un container usa-e-getta,
senza mai riavviare il demone condiviso.

Prepara l'ambiente:

    cd docker/ed1/cap05/start

### Fase 1 — Il malinteso del comando unico (5.1)

Quando digiti docker run, l'istinto dice «il programma docker ha avviato il container». È falso: docker è
solo un client che traduce la tua richiesta in una chiamata API e la spedisce al demone dockerd. È il
demone, non il client, a possedere container, immagini e reti.

### Fase 2 — Il socket è l'API (5.2 — TODO 1)

Apri start/lacatena.sh e completa il **TODO 1**: chiedi al demone la sua versione parlando direttamente
al socket UNIX con curl, e registrala —

    ver=$(curl -s --unix-socket "$SOCK" http://localhost/version \
            | grep -o '"Version":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "api_version=$ver" > "$OUT/chain.txt"

Ogni comando docker è, in fondo, una richiesta HTTP a questo socket.

### Fase 3 — Il custode: il genitore del container (5.5 — TODO 2)

Lo script avvia un container usa-e-getta e ne trova il PID sull'host. Completa il **TODO 2**: registra il
nome del processo GENITORE, letto da /proc/<ppid>/comm. Sarà un containerd-shim — il custode — non
dockerd.

    echo "parent_comm=$(cat "/proc/$ppid/comm")" >> "$OUT/chain.txt"

### Fase 4 — Sopra lo shim (5.4 — TODO 3)

Completa il **TODO 3**: sali di un gradino e registra il nome del processo NONNO (il genitore del
genitore, dal campo 4 di /proc/<ppid>/stat). È systemd o containerd, non dockerd: la prova che il
container non è figlio del demone, ed è per questo che riavviare dockerd non lo uccide.

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- lacatena.sh registra la versione ottenuta dal socket (TODO 1).
- Registra il genitore (uno shim) del container (TODO 2).
- Registra il nonno (systemd/containerd, non dockerd) (TODO 3).
- run.sh stampa OK 1..4 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh segue la catena e verifica, punto per punto:

- **OK 1** — la CLI è un client API: il socket grezzo risponde con la versione del demone.
- **OK 2** — la stessa API elenca il container in esecuzione (la CLI si limita a formattarlo).
- **OK 3** — il genitore del container è lo shim custode, non il demone.
- **OK 4** — sopra lo shim c'è systemd/containerd, non dockerd: ecco perché il live-restore funziona.

## Domande di riflessione

**a.** docker è solo un client. Come lo hai dimostrato con curl? Perché l'errore tipico è «Cannot connect
to the Docker daemon» e non «docker è rotto»? E perché scrivere su quel socket equivale a essere root
sull'host (capitolo 23)?

**b.** Se runc crea il container e poi esce, chi lo tiene in vita? Rispondi con la prova dell'albero dei
processi (genitore e nonno) e spiega perché questo rende possibile aggiornare il demone senza fermare i
container — il live-restore.

**c.** Per vedere il live-restore dal vivo si abilita e si riavvia il demone (systemctl restart docker con
live-restore: true). Perché questo laboratorio NON automatizza quel passo? In quale ambiente è sicuro
provarlo, e come lo isoleresti su una macchina condivisa?

## Pulizia

Niente da smontare: il container usa-e-getta è avviato con --rm e viene rimosso dallo script (trap) a
fine esecuzione; il test lavora in una cartella temporanea che ripulisce da sé. Il demone non viene mai
riavviato, quindi nessun altro container sull'host è toccato.

## Dove porta

Hai trasformato «Docker» da scatola nera a catena leggibile. Il **capitolo 6** fa un passo di lato per
capire perché questa catena è fatta di pezzi intercambiabili: gli standard OCI, e il file config.json che
runc legge ed esegue — la ricetta esatta in cui tutta la Parte 1 si condensa.
