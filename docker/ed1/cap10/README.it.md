# Capitolo 10 — Il comandante e gli ordini

**Livello:** Intermedio

Hai dato un comando di default con CMD; ma chi comanda davvero alla partenza? Un
container ha un solo processo al posto d'onore — il PID 1 che hai incontrato nel
capitolo 7 — e due istruzioni decidono chi è e cosa esegue: ENTRYPOINT e CMD. La
metafora è quella del comandante e degli ordini: ENTRYPOINT è il comandante fisso
della nave, CMD sono gli ordini di default, che si possono cambiare alla partenza.
In questo laboratorio li combini, vedi come gli argomenti passati a docker run
sovrascrivono CMD ma non ENTRYPOINT, e verifichi che la forma esatta con cui li
scrivi decide se il tuo processo è PID 1 o finisce avvolto in una shell.

## Obiettivi

- Distinguere ENTRYPOINT (l'eseguibile fisso) da CMD (gli argomenti di default) e
  vederli combinati (10.2, 10.3, 10.5).
- Osservare che gli argomenti passati a docker run sovrascrivono CMD ma lasciano
  intatto ENTRYPOINT (10.5).
- Capire la forma exec contro la forma shell: la exec rende il tuo processo PID 1
  (10.1, 10.4).
- Ricollegare il PID 1 ai segnali del capitolo 7: chi è PID 1 riceve SIGTERM.

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter
  usare Docker.
- Il capitolo 7 (il PID 1 e i segnali) e il capitolo 9 (COPY, CMD): qui li metti
  insieme.

## Lo scenario

In start/ trovi un Dockerfile incompleto e entry.sh, uno script che stampa il
proprio PID e gli argomenti ricevuti. Il Dockerfile parte da busybox ma non imbarca
lo script, non nomina il comandante e non dà ordini di default. Colmi tre lacune
(TODO 1..3). Immagine usa-e-getta, nessun privilegio, il demone condiviso non si
tocca.

Prepara l'ambiente:

    cd docker/ed1/cap10/start

### Fase 1 — Il processo di avvio: chi è PID 1 (10.1, 10.4)

Un container esegue un processo come PID 1. Il modo in cui scrivi ENTRYPOINT/CMD
decide chi è: la **forma exec** (un array JSON, come ["/entry.sh"]) esegue
direttamente il tuo programma, che diventa PID 1; la **forma shell** (una stringa)
lo avvolge in /bin/sh -c, e allora è la shell a essere PID 1 — con le conseguenze
sui segnali viste nel capitolo 7.

### Fase 2 — Imbarcare lo script (10.3 — TODO 1)

Apri start/Dockerfile e completa il **TODO 1**: copia entry.sh dentro l'immagine.
Nel contesto è già eseguibile, e COPY ne preserva i permessi.

    COPY entry.sh /entry.sh

### Fase 3 — Il comandante fisso: ENTRYPOINT (10.3 — TODO 2)

Completa il **TODO 2**: dichiara ENTRYPOINT in forma exec, così lo script è il
processo fisso all'avvio — ed è PID 1.

    ENTRYPOINT ["/entry.sh"]

### Fase 4 — Gli ordini di default: CMD (10.5 — TODO 3)

Completa il **TODO 3**: dai a ENTRYPOINT degli argomenti di default con CMD. Non è
un secondo comando: è la lista di argomenti che verrà passata a ENTRYPOINT, e che
docker run può sovrascrivere.

    CMD ["default"]

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- Il Dockerfile copia entry.sh nell'immagine (TODO 1).
- Dichiara ENTRYPOINT in forma exec (TODO 2).
- Dà argomenti di default con CMD (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh costruisce l'immagine e verifica, punto per punto:

- **OK 1** — ENTRYPOINT più CMD: avviando senza argomenti, ENTRYPOINT esegue con
  gli argomenti di default di CMD (args = default).
- **OK 2** — gli argomenti di docker run sovrascrivono CMD ma non ENTRYPOINT:
  avviando con «foo bar», args = foo bar e il comandante resta entry.sh.
- **OK 3** — forma exec: lo script è PID 1 (self_pid = 1), quindi riceve i segnali
  in prima persona (capitolo 7), senza una shell che lo avvolge.

## Domande di riflessione

**a.** ENTRYPOINT e CMD non sono due comandi alternativi: come si combinano quando
ci sono entrambi, e cosa succede esattamente lanciando docker run immagine
argomento? Perché CMD da solo si sovrascrive del tutto, mentre con ENTRYPOINT
diventa solo la lista di argomenti di default?

**b.** La forma exec (array JSON) e la forma shell (stringa) sembrano equivalenti
ma non lo sono: perché la exec rende il tuo processo PID 1, mentre la shell lo
avvolge in sh -c che diventa PID 1? Collega la risposta al capitolo 7: perché la
forma shell può far «impiegare dieci secondi» a fermarsi un container?

**c.** Quando conviene solo CMD, solo ENTRYPOINT, o entrambi? Pensa a un'immagine
«eseguibile» (un tool che prende sempre argomenti) contro un'immagine generica, e
a cosa serve --entrypoint per scavalcare il comandante all'avvio.

## Pulizia

Niente da smontare a mano: l'immagine di prova è rimossa dallo script (docker rmi,
più un trap di sicurezza) a fine esecuzione; il test non lascia container.
L'immagine base busybox resta in cache (condivisa). Il demone non viene mai
riavviato.

## Dove porta

Sai chi comanda un container e come. La **Parte 3** si chiude guardando alla
velocità e alla dimensione: il **capitolo 11** entra nella cache strategica e nei
Multi-Stage Builds — come ordinare e spezzare i layer del capitolo 8 perché le
build siano veloci e le immagini leggere. Per il riferimento delle istruzioni, vedi
le appendici del volume.
