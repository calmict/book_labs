# Capitolo 26 — La scatola nera del container muto

**Livello:** Cloud Architect

Prima o poi arriva il container che non parte, non dice niente, e magari continua a
ripartire da solo. I log sono vuoti — muto — e l'istinto è arrendersi. Ma un container
non è mai davvero muto: anche quando non scrive una riga, lascia una scatola nera. docker
inspect racconta com'è morto — l'exit code, che come hai visto nel capitolo 7 è già una
diagnosi — e quante volte è ripartito prima di arrendersi, il segno del crash loop. In
questo laboratorio ricostruisci la storia di container con sintomi diversi: un crash
silenzioso, un OOM kill, un comando inesistente e un'immagine senza shell. La diagnosi
parte dai fatti osservabili e arriva ogni volta a un rimedio mirato.

## Obiettivi

- Riconoscere un container «muto»: i log sono vuoti, non c'è nulla da leggere lì (26.1).
- Leggere la scatola nera con docker inspect: l'exit code, la vera diagnosi (26.2, 26.4).
- Riconoscere il crash loop dal contatore dei riavvii e dallo stato finale (26.3).
- Collegare l'exit code alle sue cause (capitolo 7): 42, 137, 143, 127... (26.4).
- Confermare un OOM kill con exit 137 e State.OOMKilled, non con il solo numero (26.4).
- Distinguere il 127 restituito dalla shell dal rifiuto di un eseguibile diretto inesistente
  (26.4).
- Osservare i processi di un container senza shell condividendone il PID namespace (26.4).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter usare
  Docker.
- Il capitolo 7 (ciclo di vita ed exit code) e il 25 (log e metriche): qui li usi quando
  qualcosa va storto.

## Lo scenario

In start/ trovi troubleshoot.sh: uno script che avvia un container che esce in silenzio con un
codice non-zero e una restart policy, e dovrebbe leggerne log, exit code e riavvii — ma le
tre letture mancano. Lo script estende poi la diagnosi agli altri tre sintomi. Colmi sei
lacune (TODO 1..6). Container e immagine sono usa-e-getta, il demone non si tocca.

Prepara l'ambiente:

    cd docker/ed1/cap26/start

### Fase 1 — Il silenzio: log vuoti (26.1 — TODO 1)

Apri start/troubleshoot.sh e completa il **TODO 1**: leggi i log del container. Sono vuoti: il
container è morto senza stampare nulla. Dai log, qui, non ricavi niente.

    logs=$(docker logs "$C" 2>&1)

### Fase 2 — La scatola nera: l'exit code (26.2, 26.4 — TODO 2)

Completa il **TODO 2**: leggi l'exit code da docker inspect. Anche senza log, il codice di
uscita è già una diagnosi — qui 42, un errore dell'applicazione.

    exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$C")

### Fase 3 — Il crash loop: i riavvii (26.3 — TODO 3)

Completa il **TODO 3**: leggi quante volte il container è ripartito e il suo stato finale.
Con una restart policy, un container che crasha subito riparte in loop finché la policy
non si arrende.

    restart_count=$(docker inspect -f '{{.RestartCount}}' "$C")
    status=$(docker inspect -f '{{.State.Status}}' "$C")

### Fase 4 — Exit 137: ucciso, non «andato in errore» (26.4 — TODO 4)

Completa il **TODO 4**: avvia un processo con un tetto di memoria di 16 MiB e fagli
richiedere un buffer da 64 MiB. Attendi che termini, poi leggi da docker inspect sia
State.ExitCode sia State.OOMKilled. Il 137 è 128+9, quindi segnala SIGKILL; soltanto
OOMKilled=true attribuisce qui il segnale all'esaurimento della memoria.

Il rimedio è correggere o limitare l'allocazione dell'applicazione e dimensionare il tetto
in base al consumo misurato, non aumentarlo alla cieca.

    oom_exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$OOM_C")
    oom_killed=$(docker inspect -f '{{.State.OOMKilled}}' "$OOM_C")

### Fase 5 — Exit 127: il comando che non c'è (26.4 — TODO 5)

Completa il **TODO 5**: esegui lo stesso comando inesistente prima tramite sh -c e poi
direttamente. Nel primo caso parte una shell, che non trova il comando e restituisce 127;
State.Error resta vuoto. Nel secondo Docker non riesce ad avviare il processo: il container
resta in stato created e State.Error spiega il rifiuto. Il codice restituito dal client non
trasforma il secondo caso in un exit della shell.

Il rimedio è correggere CMD o ENTRYPOINT e verificare che il binario esista nell'immagine e
sia raggiungibile tramite PATH; se si voleva usare una funzione della shell, occorre invocare
esplicitamente una shell presente nell'immagine.

    shell_exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$SHELL_C")
    direct_error=$(docker inspect -f '{{.State.Error}}' "$DIRECT_C")

### Fase 6 — Guardare dentro un container senza shell (26.4 — TODO 6)

Completa il **TODO 6**: fai scrivere allo script il Dockerfile qui sotto, costruisci una
piccola immagine scratch con il solo binario statico di sleep, dimostra che docker exec non
può avviarvi sh, quindi lancia un container helper che condivide il PID namespace del target
e usa ps dall'esterno. Il Dockerfile lo genera lo script perché la cartella di lavoro la crea
run.sh a ogni esecuzione: nell'heredoc, corpo e riga EOF di chiusura vanno a colonna 0.

Questa strada senza privilegi mostra la lista dei processi, ma **non** il filesystem del
target e non sostituisce nsenter in generale. Il rimedio operativo è usare un'immagine di
debug separata con gli strumenti necessari, senza aggiungere una shell all'immagine di
produzione; per filesystem o namespace ulteriori servono tecniche e privilegi appropriati.

    FROM busybox:1.36.1-uclibc AS source
    FROM scratch
    COPY --from=source /bin/busybox /sleep
    ENTRYPOINT ["/sleep", "30"]

    docker run --rm --pid="container:$SHELLLESS_C" busybox ps

Quando i sei TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- troubleshoot.sh legge i log del container (vuoti) (TODO 1).
- Legge l'exit code da docker inspect (TODO 2).
- Legge il contatore dei riavvii e lo stato finale (TODO 3).
- Verifica exit 137 insieme a State.OOMKilled (TODO 4).
- Distingue il 127 della shell dal rifiuto dell'esecuzione diretta (TODO 5).
- Ispeziona i processi del container senza shell tramite un PID namespace condiviso (TODO 6).
- run.sh stampa OK 1..6 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — il container è muto: docker logs non restituisce nulla.
- **OK 2** — docker inspect rivela l'exit code (42): la diagnosi arriva da lì, non dai log.
- **OK 3** — il crash loop è visibile: il contatore dei riavvii è maggiore di zero e lo
  stato finale è «exited» (la policy si è arresa).
- **OK 4** — exit 137 e OOMKilled=true confermano insieme che il processo è stato ucciso
  per esaurimento della memoria.
- **OK 5** — la shell restituisce 127; l'esecuzione diretta viene rifiutata prima che il
  processo parta, con stato ed errore diversi.
- **OK 6** — sh non parte nel container scratch, mentre il container helper vede il suo
  processo condividendo il PID namespace.

## Domande di riflessione

**a.** Un container può essere muto per tante ragioni: è crashato prima di stampare, scrive
su un file invece che su stdout, il PID 1 non inoltra l'output (capitolo 10), o il buffer
non è stato svuotato. Come si diagnostica quando i log non aiutano — e perché docker
inspect e l'exit code sono il primo appiglio?

**b.** Una restart policy (no, on-failure, always, unless-stopped) decide se e quante volte
un container riparte. Perché un always su un container che crasha subito è un loop
potenzialmente infinito, e come lo smorza il backoff crescente di Docker? In che modo
RestartCount e lo stato lo rivelano — e come si chiama, in Kubernetes, lo stesso fenomeno
(CrashLoopBackOff)?

**c.** Perché né 137 né 127 bastano da soli a chiudere la diagnosi? Quale controprova offre
docker inspect per l'OOM, quale differenza separa shell form ed esecuzione diretta, e che
cosa può — e non può — osservare il container helper che condivide soltanto il PID namespace?

## Pulizia

Niente da smontare a mano: tutti i container cap26 e l'immagine scratch costruita dal test
sono rimossi dallo script, anche in caso di errore, tramite un trap di sicurezza. Le immagini
base busybox restano in cache. Il demone non viene mai riavviato.

## Dove porta

Sai ricostruire la storia di un container anche quando tace. Il **capitolo 27** chiude la
Parte 7 e il manuale con il day-2 vero e proprio: la manutenzione — pulizia di immagini,
container e volumi orfani, gestione dello spazio — e gli orizzonti oltre il singolo host,
il ponte verso l'orchestrazione. Per il riferimento dei comandi, vedi le appendici del
volume.
