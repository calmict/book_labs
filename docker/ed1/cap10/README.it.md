# Capitolo 10 — Il comandante e gli ordini

**Livello:** Intermedio

Hai dato un comando di default con CMD; ma chi comanda davvero alla partenza? Un
container ha un solo processo al posto d'onore — il PID 1 che hai incontrato nel
capitolo 7 — e due istruzioni decidono chi è e cosa esegue: ENTRYPOINT e CMD. La
metafora è quella del comandante e degli ordini: ENTRYPOINT è il comandante fisso
della nave, CMD sono gli ordini di default, che si possono cambiare alla partenza.
In questo laboratorio li combini, vedi come gli argomenti passati a docker run
sovrascrivono CMD ma non ENTRYPOINT, e poi cronometri l'arresto dello stesso
script avviato in tre modi diversi: la differenza tra fermarsi in un secondo ed
essere uccisi allo scadere del tempo si misura, e non è dove ti aspetti.

## Obiettivi

- Distinguere ENTRYPOINT (l'eseguibile fisso) da CMD (gli argomenti di default) e
  vederli combinati (10.2, 10.3, 10.5).
- Osservare che gli argomenti passati a docker run sovrascrivono CMD ma lasciano
  intatto ENTRYPOINT (10.5).
- Capire la forma exec contro la forma shell: la exec rende il tuo processo PID 1
  (10.1, 10.4).
- Ricollegare il PID 1 ai segnali del capitolo 7: chi è PID 1 riceve SIGTERM — e
  chi non lo gestisce viene ucciso allo scadere del periodo di grazia.
- Misurare la condizione esatta del rallentamento: non è la forma shell in sé, è
  la shell che resta in mezzo (10.4).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md). Il tuo utente deve poter
  usare Docker.
- Il capitolo 7 (il PID 1 e i segnali) e il capitolo 9 (COPY, CMD): qui li metti
  insieme.

## Lo scenario

In start/ trovi un Dockerfile incompleto e entry.sh, uno script che stampa il
proprio PID e gli argomenti ricevuti, e che con l'argomento «serve» resta vivo
gestendo SIGTERM. Il Dockerfile parte da busybox ma non imbarca lo script, non
nomina il comandante e non dà ordini di default. Colmi tre lacune (TODO 1..3).

Accanto trovi due Dockerfile già completi — Dockerfile.shell-stays e
Dockerfile.shell-alone: non sono esercizi, sono i termini di paragone per la fase
5. Immagini usa-e-getta, nessun privilegio, il demone condiviso non si tocca.

Prepara l'ambiente:

    cd docker/ed1/cap10/start

### Fase 1 — Il processo di avvio: chi è PID 1 (10.1, 10.4)

Un container esegue un processo come PID 1. Il modo in cui scrivi ENTRYPOINT/CMD
decide chi è: la **forma exec** (un array JSON, come ["/entry.sh"]) esegue
direttamente il tuo programma, che diventa PID 1; la **forma shell** (una stringa)
lo avvolge in /bin/sh -c. Che poi la shell resti davvero al posto d'onore dipende
da cosa le hai chiesto di fare: lo verificherai tu stesso nella fase 5.

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

### Fase 5 — Tre partenze, tre arresti (10.4)

Qui non c'è niente da scrivere: guarda i due Dockerfile già pronti e capisci cosa
cambia. Sono lo stesso script, avviato in tre modi.

- La tua immagine, forma exec: ENTRYPOINT ["/entry.sh"] con argomento «serve».
- Dockerfile.shell-stays, forma shell con qualcosa dopo lo script:

      CMD /entry.sh serve; echo stopped

- Dockerfile.shell-alone, forma shell con il solo script:

      CMD /entry.sh serve

Il test avvia i tre container e li ferma con docker stop, accorciando a cinque
secondi il periodo di grazia che di default è dieci (capitolo 7), per non farti
aspettare. Poi cronometra, legge il codice di uscita e chiede allo script quale
PID si è visto assegnare. Il risultato dice più della regola che hai in mente:
uno solo dei tre container muore di SIGKILL, e non è quello che avresti indicato
guardando la sola forma del CMD.

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- Il Dockerfile copia entry.sh nell'immagine (TODO 1).
- Dichiara ENTRYPOINT in forma exec (TODO 2).
- Dà argomenti di default con CMD (TODO 3).
- run.sh stampa OK 1..5 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh costruisce le tre immagini e verifica, punto per punto:

- **OK 1** — ENTRYPOINT più CMD: avviando senza argomenti, ENTRYPOINT esegue con
  gli argomenti di default di CMD (args = default).
- **OK 2** — gli argomenti di docker run sovrascrivono CMD ma non ENTRYPOINT:
  avviando con «foo bar», args = foo bar e il comandante resta entry.sh.
- **OK 3** — forma exec: lo script è PID 1 (self_pid = 1), quindi riceve i segnali
  in prima persona (capitolo 7), senza una shell che lo avvolge.
- **OK 4** — i tempi di arresto a confronto: in forma exec lo script è PID 1,
  riceve SIGTERM e il container si ferma in circa un secondo con codice 0; con la
  shell che resta in mezzo lo script non è più PID 1, il segnale si ferma alla
  shell, il periodo di grazia scade e il container viene ucciso, con codice 137.
- **OK 5** — la condizione dietro la regola: se alla shell chiedi solo di eseguire
  lo script, la shell di busybox si sostituisce con lui invece di aspettarlo. Il
  PID 1 torna a essere lo script, l'arresto è di nuovo immediato. A costare non è
  la forma shell: è la shell che resta.

## Domande di riflessione

**a.** ENTRYPOINT e CMD non sono due comandi alternativi: come si combinano quando
ci sono entrambi, e cosa succede esattamente lanciando docker run immagine
argomento? Perché CMD da solo si sovrascrive del tutto, mentre con ENTRYPOINT
diventa solo la lista di argomenti di default?

**b.** Nella fase 5 due container su tre si fermano subito, e i due che usano la
forma shell si comportano in modo opposto tra loro. Che cosa distingue davvero il
caso lento — la forma con cui hai scritto il CMD, o qualcos'altro? E perché un
PID 1 che non gestisce SIGTERM non muore, mentre lo stesso processo con un PID
qualsiasi morirebbe? Collega la risposta al capitolo 7.

**c.** Quando conviene solo CMD, solo ENTRYPOINT, o entrambi? Pensa a un'immagine
«eseguibile» (un tool che prende sempre argomenti) contro un'immagine generica, e
a cosa serve --entrypoint per scavalcare il comandante all'avvio.

## Pulizia

Niente da smontare a mano: le tre immagini di prova sono rimosse dallo script
(docker rmi, più un trap di sicurezza) a fine esecuzione, e ogni container avviato
per il cronometro viene fermato e rimosso subito dopo la misura. L'immagine base
busybox resta in cache (condivisa). Il demone non viene mai riavviato.

## Dove porta

Sai chi comanda un container e come. La **Parte 3** si chiude guardando alla
velocità e alla dimensione: il **capitolo 11** entra nella cache strategica e nei
Multi-Stage Builds — come ordinare e spezzare i layer del capitolo 8 perché le
build siano veloci e le immagini leggere. Per il riferimento delle istruzioni, vedi
le appendici del volume.
