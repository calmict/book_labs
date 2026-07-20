# Capitolo 15 — Il numero sul badge

**Livello:** Avanzato

Hai imparato a girare come utente non-root (capitolo 12) e a montare dati condivisi
(capitolo 14). Metti insieme le due cose e inciampi nel classico: il container
non-root prova a scrivere nel volume e si sente rispondere «permesso negato». La
ragione è che sul confine di un mount i permessi non si leggono per nome ma per
numero: conta l'UID: un badge numerico. Se il numero del container non possiede i
file montati, non scrive — punto. In questo laboratorio riproduci il mismatch, lo
risolvi facendo girare il container con l'UID giusto, e verifichi che il numero
attraversa il confine tale e quale: l'UID N dentro è l'UID N sull'host.

## Obiettivi

- Vedere che su un mount condiviso i permessi valgono per UID/GID numerico, non per
  nome utente (15.1).
- Riprodurre il problema: un container con UID che non possiede la cartella non può
  scrivere (15.2).
- Risolverlo facendo girare il container con l'UID che possiede i file (--user)
  (15.3).
- Verificare che l'UID non viene tradotto: il file creato dal container è di
  proprietà dello stesso UID sull'host (15.4).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md), nativo (il bind mount usa i
  permessi reali dell'host). Il tuo utente deve poter usare Docker.
- Il capitolo 12 (container non-root) e il capitolo 14 (bind mount): qui li fai
  scontrare coi permessi.

## Lo scenario

In start/ trovi ipermessi.sh: uno script che prepara una cartella dell'host di tua
proprietà, la monta in un container e dovrebbe mostrare il mismatch e la sua cura —
ma le tre prove chiave mancano. Colmi tre lacune (TODO 1..3). Container usa-e-getta
(--rm) e una cartella temporanea: nessun privilegio, il demone non si tocca.

Prepara l'ambiente:

    cd docker/ed1/cap15/start

### Fase 1 — Il problema: badge sbagliato (15.2 — TODO 1)

Apri start/ipermessi.sh e completa il **TODO 1**: la cartella dell'host è di
proprietà del tuo UID. Fai girare un container con un UID diverso (non-root) che
prova a scrivere nel mount: viene respinto, perché quel numero non possiede la
cartella e non è che «other», senza permesso di scrittura.

    mismatch=$(docker run --rm --user "$OTHER_UID" -v "$HOSTDIR:/data" busybox sh -c 'touch /data/x 2>/dev/null && echo WROTE || echo DENIED')

### Fase 2 — La cura: badge giusto (15.3 — TODO 2)

Completa il **TODO 2**: rifai la stessa scrittura, ma con il container che gira come
l'UID che possiede la cartella. Stesso mount, stesso comando: cambia solo il numero,
e ora la scrittura passa.

    match=$(docker run --rm --user "$HOST_UID" -v "$HOSTDIR:/data" busybox sh -c 'touch /data/ok 2>/dev/null && echo WROTE || echo DENIED')

### Fase 3 — Il numero attraversa il confine (15.4 — TODO 3)

Completa il **TODO 3**: guarda, dall'host, di chi è il file appena creato dal
container. Non c'è traduzione: l'UID del container è lo stesso UID sull'host.

    owner_uid=$(stat -c '%u' "$HOSTDIR/ok" 2>/dev/null || echo NONE)

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- ipermessi.sh riproduce il mismatch: un UID che non possiede la cartella è respinto
  (TODO 1).
- Risolve facendo girare il container con l'UID proprietario (TODO 2).
- Verifica dall'host la proprietà del file creato (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — mismatch: il container con un UID che non possiede la cartella non
  scrive (risultato DENIED).
- **OK 2** — cura: lo stesso container, con l'UID proprietario, scrive (risultato
  WROTE).
- **OK 3** — nessuna traduzione: il file creato dal container è di proprietà, sull'
  host, dello stesso UID con cui girava il container.

## Domande di riflessione

**a.** Sul confine di un mount i permessi valgono per UID/GID numerico, non per nome
utente: perché? Cosa vede davvero il kernel quando il container scrive, e perché il
nome «appuser» dentro l'immagine (capitolo 12) è irrilevante rispetto al numero che
gli corrisponde?

**b.** Ci sono tre modi di far combaciare i numeri: far girare il container con
--user pari all'UID che possiede i file; fare chown della cartella all'UID del
container; oppure creare nell'immagine l'utente con lo stesso UID numerico dei dati.
Quali sono i pro e i contro di ciascuno, in sviluppo e in produzione?

**c.** Lo USER namespace (capitolo 2) può rimappare gli UID: container-root diventa
un subuid non privilegiato sull'host. Come cambia il quadro con userns o in modalità
rootless, e perché — senza rimappatura — l'UID N nel container resta esattamente
l'UID N sull'host?

## Pulizia

Niente da smontare a mano: i container sono usa-e-getta (--rm) e la cartella
condivisa vive in una directory temporanea che run.sh ripulisce da sé. L'immagine
base busybox resta in cache (condivisa). Il demone non viene mai riavviato.

## Dove porta

Con questo capitolo la Parte 4 è completa: sai dove tenere i dati, con quale
montaggio e con quali permessi. La **Parte 5** cambia dimensione: non più lo storage
ma la **rete**. Il **capitolo 16** apre i labirinti del networking — come Docker
manipola lo stack di rete di Linux (namespace di rete, veth, bridge) per dare a ogni
container il suo indirizzo. Per il riferimento dei comandi, vedi le appendici del
volume.
