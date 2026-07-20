# Capitolo 7 — Morire con grazia

**Livello:** Intermedio

Chiudiamo l'architettura del motore seguendo un container dalla nascita alla morte — e quasi tutte le
trappole hanno la stessa radice: quel PID 1 che hai incontrato «a mani nude» nel capitolo 1. In questo
laboratorio confronti due container di fronte a docker stop: uno il cui PID 1 ignora SIGTERM, e uno con un
vero init al posto giusto. Misuri la differenza — dieci secondi contro un istante — e capisci, con il
cronometro alla mano, perché tanti container «ci mettono sempre dieci secondi» a fermarsi.

## Obiettivi

- Osservare la sequenza di docker stop: SIGTERM, attesa (grace period), poi SIGKILL (7.3).
- Riconoscere la trappola del PID 1: un processo che ignora SIGTERM attende tutto il grace (7.3).
- Curare la trappola con --init (tini) come PID 1, che inoltra il segnale (7.5).
- Leggere gli exit code come diagnosi: 137 (SIGKILL) contro 143 (SIGTERM pulito) (7.3).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter usare Docker.
- Il PID 1 «a mani nude» del capitolo 1 e i segnali come concetto: qui presentano il conto.

## Lo scenario

In start/ trovi congrazia.sh: uno script che dovrebbe avviare due container e cronometrarne lo stop, ma
non cronometra e non registra l'exit code. Colmi tre lacune (TODO 1..3) usando container usa-e-getta,
senza mai riavviare il demone.

Prepara l'ambiente:

    cd docker/ed1/cap07/start

### Fase 1 — Gli stati e la sequenza di stop (7.1, 7.3)

Un container non è acceso o spento: attraversa stati (created, running, exited). E quando lo fermi, Docker
non lo «stacca dalla corrente»: gli manda SIGTERM, aspetta il grace period, e solo se è ancora vivo manda
SIGKILL. Come reagisce il PID 1 a quel primo segnale fa tutta la differenza.

### Fase 2 — Cronometrare lo stop (7.3 — TODO 1)

Apri start/congrazia.sh e completa il **TODO 1**, dentro la funzione measure: ferma il container con il
grace period e cronometra l'operazione.

    local t0 t1
    t0=$(date +%s%N)
    docker stop -t "$GRACE" "$n" >/dev/null
    t1=$(date +%s%N)

### Fase 3 — L'exit code come diagnosi (7.3 — TODO 3)

Completa il **TODO 3**: stampa i millisecondi trascorsi e l'exit code, letto con docker inspect. L'exit
code racconta tutto: 137 (SIGKILL) se il PID 1 ha ignorato SIGTERM, 143 (SIGTERM) se si è fermato pulito.

    echo "$(( (t1 - t0) / 1000000 )) $(docker inspect -f '{{.State.ExitCode}}' "$n")"

### Fase 4 — Il vero init (7.5 — TODO 2)

Il container A avvia sleep come PID 1, che ignora SIGTERM. Completa il **TODO 2**: fai avviare il
container B con --init, così tini diventa PID 1 e inoltra SIGTERM a sleep, che allora termina subito.

    read -r b_ms b_code < <(measure b --init)

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- measure cronometra lo stop con il grace period (TODO 1) e registra l'exit code (TODO 3).
- Il container B usa --init (TODO 2).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED: A attende il grace ed esce 137, B si ferma subito ed esce
  143, e A è nettamente più lento di B.

## Come viene verificato

solution/run.sh avvia i due container e li cronometra, verificando:

- **OK 1** — A ignora SIGTERM: attende (quasi) tutto il grace ed è ucciso con SIGKILL (exit 137).
- **OK 2** — B con --init si ferma all'istante con un SIGTERM pulito (exit 143).
- **OK 3** — la differenza è il PID 1: A è molto più lento di B; --init fa la differenza.

## Domande di riflessione

**a.** Perché il container A impiega tutto il grace period a fermarsi? Collega la risposta al trattamento
speciale che il kernel riserva ai segnali di PID 1, e spiega perché questa è la vera causa dei container
che «ci mettono sempre dieci secondi».

**b.** Il container B si ferma all'istante. Cosa cambia esattamente con --init, e perché il rimedio non è
riscrivere l'applicazione ma darle un init al posto giusto? Cosa fa tini, oltre a inoltrare i segnali?

**c.** 137 e 143 sono due diagnosi. Cosa significa ciascuno, e perché li rivedrai nel capitolo 26? Perché
progettare per SIGTERM — invece di subire SIGKILL — è una questione di sicurezza dei dati, non di
eleganza?

## Pulizia

Niente da smontare: entrambi i container sono rimossi dallo script (docker rm, più un trap di sicurezza)
a fine esecuzione; il test lavora in una cartella temporanea che ripulisce da sé. Il demone non viene mai
riavviato.

## Dove porta

Con questo capitolo il motore non ha più segreti: sai chi esegue un container (cap5), secondo quali regole
(cap6) e come vive e muore (cap7). Comincia l'artigianato. La **Parte 3** apre con il **capitolo 8**:
l'anatomia di un'immagine — layer, digest, manifest — e da lì costruirai Dockerfile veri, ottimizzati e
sicuri. Per il riferimento rapido, vedi le appendici del volume.
