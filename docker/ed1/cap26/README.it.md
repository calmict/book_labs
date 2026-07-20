# Capitolo 26 — La scatola nera del container muto

**Livello:** Cloud Architect

Prima o poi arriva il container che non parte, non dice niente, e magari continua a
ripartire da solo. I log sono vuoti — muto — e l'istinto è arrendersi. Ma un container
non è mai davvero muto: anche quando non scrive una riga, lascia una scatola nera. docker
inspect racconta com'è morto — l'exit code, che come hai visto nel capitolo 7 è già una
diagnosi — e quante volte è ripartito prima di arrendersi, il segno del crash loop. In
questo laboratorio prendi un container che crasha in silenzio, con una restart policy che
lo fa ripartire, e ne ricostruisci la storia senza una sola riga di log: dall'exit code e
dal contatore dei riavvii.

## Obiettivi

- Riconoscere un container «muto»: i log sono vuoti, non c'è nulla da leggere lì (26.1).
- Leggere la scatola nera con docker inspect: l'exit code, la vera diagnosi (26.2, 26.4).
- Riconoscere il crash loop dal contatore dei riavvii e dallo stato finale (26.3).
- Collegare l'exit code alle sue cause (capitolo 7): 42, 137, 143, 127... (26.4).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter usare
  Docker.
- Il capitolo 7 (ciclo di vita ed exit code) e il 25 (log e metriche): qui li usi quando
  qualcosa va storto.

## Lo scenario

In start/ trovi idiag.sh: uno script che avvia un container che esce in silenzio con un
codice non-zero e una restart policy, e dovrebbe leggerne log, exit code e riavvii — ma le
tre letture mancano. Colmi tre lacune (TODO 1..3). Container usa-e-getta (rm), il demone
non si tocca.

Prepara l'ambiente:

    cd docker/ed1/cap26/start

### Fase 1 — Il silenzio: log vuoti (26.1 — TODO 1)

Apri start/idiag.sh e completa il **TODO 1**: leggi i log del container. Sono vuoti: il
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

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- idiag.sh legge i log del container (vuoti) (TODO 1).
- Legge l'exit code da docker inspect (TODO 2).
- Legge il contatore dei riavvii e lo stato finale (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — il container è muto: docker logs non restituisce nulla.
- **OK 2** — docker inspect rivela l'exit code (42): la diagnosi arriva da lì, non dai log.
- **OK 3** — il crash loop è visibile: il contatore dei riavvii è maggiore di zero e lo
  stato finale è «exited» (la policy si è arresa).

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

**c.** L'exit code è una diagnosi (capitolo 7): 42 è un errore dell'applicazione, 137 è
SIGKILL (spesso l'OOM killer), 143 è SIGTERM, 127 «comando non trovato», 126 «non
eseguibile». Perché leggere l'exit code è sempre il primo passo del troubleshooting, prima
ancora dei log?

## Pulizia

Niente da smontare a mano: il container è rimosso dallo script (docker rm -f, più un trap
di sicurezza). L'immagine base busybox resta in cache. Il demone non viene mai riavviato.

## Dove porta

Sai ricostruire la storia di un container anche quando tace. Il **capitolo 27** chiude la
Parte 7 e il manuale con il day-2 vero e proprio: la manutenzione — pulizia di immagini,
container e volumi orfani, gestione dello spazio — e gli orizzonti oltre il singolo host,
il ponte verso l'orchestrazione. Per il riferimento dei comandi, vedi le appendici del
volume.
