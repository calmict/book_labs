# Capitolo 15 — Il numero sul badge

**Livello:** Avanzato

Hai imparato a girare come utente non-root (capitolo 12) e a montare dati condivisi
(capitolo 14). Metti insieme le due cose e inciampi nel classico: il container
non-root prova a scrivere nel volume e si sente rispondere «permesso negato». La
ragione è che sul confine di un mount i permessi non si leggono per nome ma per
numero: conta l'UID: un badge numerico. Se il numero del container non possiede i
file montati, non scrive — punto. In questo laboratorio riproduci il mismatch, lo
risolvi facendo girare il container con l'UID giusto, e verifichi che il numero
attraversa il confine tale e quale: l'UID N dentro è l'UID N sull'host. Poi
riproduci il fastidio quotidiano — il container lasciato a girare come root che ti
riempie la cartella di file che non puoi più toccare — e lo curi in altri due modi:
con USER dichiarato nell'immagine, e con un entrypoint che sistema i permessi e
cede il posto all'utente non privilegiato.

## Obiettivi

- Vedere che su un mount condiviso i permessi valgono per UID/GID numerico, non per
  nome utente (15.1).
- Riprodurre il problema: un container con UID che non possiede la cartella non può
  scrivere (15.2).
- Risolverlo facendo girare il container con l'UID che possiede i file (--user)
  (15.3).
- Verificare che l'UID non viene tradotto: il file creato dal container è di
  proprietà dello stesso UID sull'host (15.1).
- Riprodurre il problema dei file di root: un container lasciato come root scrive
  sul mount e lascia un albero che dall'host non riesci a rimuovere (15.1).
- Curarlo in due modi diversi: l'identità dichiarata nell'immagine con USER (15.2),
  e l'entrypoint che sistema i permessi da root e poi cede con exec (15.3).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md), nativo (il bind mount usa i
  permessi reali dell'host). Il tuo utente deve poter usare Docker.
- Il capitolo 12 (container non-root) e il capitolo 14 (bind mount): qui li fai
  scontrare coi permessi.

## Lo scenario

In start/ trovi ipermessi.sh: uno script che prepara una cartella dell'host di tua
proprietà, la monta in un container e dovrebbe mostrare il mismatch e le sue cure —
ma le prove chiave mancano. Colmi sei lacune (TODO 1..6).

Accanto trovi due Dockerfile già completi, Dockerfile.user e Dockerfile.entrypoint,
e lo script fixperms.sh che il secondo usa come entrypoint: sono i materiali delle
fasi 5 e 6, non ci sono TODO dentro. Container e immagini usa-e-getta e una cartella
temporanea: nessun privilegio sull'host, il demone non si tocca.

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

### Fase 4 — Il fastidio quotidiano: i file di root (15.1 — TODO 4)

Completa il **TODO 4**: lascia che un container giri come root — cioè come fa per
default — e crei una cartella con dentro un file sul mount condiviso. Poi guarda
dall'host di chi sono, e prova a rimuoverli.

    ROOTDIR="$HOSTDIR/state"
    docker run --rm -v "$HOSTDIR:/data" busybox sh -c 'mkdir -p /data/state && echo seed > /data/state/f'
    root_owner=$(stat -c '%u' "$ROOTDIR/f")
    rm -rf "$ROOTDIR" 2>/dev/null && host_cleanup=REMOVED || host_cleanup=DENIED

Appartengono a UID 0, e il tuo utente non può rimuoverli: per cancellare un file
serve il permesso di scrittura sulla cartella che lo contiene, e quella cartella
l'ha creata root. È il motivo per cui, dopo una sessione di sviluppo in container,
ti ritrovi cartelle che si tolgono solo con sudo.

### Fase 5 — Cura: l'identità nell'immagine (15.2 — TODO 5)

Completa il **TODO 5**: costruisci Dockerfile.user passando il tuo UID come
argomento di build, e scrivi con quell'immagine. Non serve nessun flag al lancio:
l'identità è dichiarata nell'immagine con USER, e ogni container che ne nasce parte
già con il numero giusto.

    docker build -q -t "$IMG_USER" --build-arg "APP_UID=$HOST_UID" -f "$HERE/Dockerfile.user" "$HERE" >/dev/null
    user_write=$(docker run --rm -v "$HOSTDIR:/data" "$IMG_USER" sh -c 'touch /data/by-user 2>/dev/null && echo WROTE || echo DENIED')
    user_owner=$(stat -c '%u' "$HOSTDIR/by-user" 2>/dev/null || echo NONE)

### Fase 6 — Cura: sistemare e cedere il posto (15.3 — TODO 6)

Completa il **TODO 6**: costruisci Dockerfile.entrypoint e lancialo sull'albero che
root ti ha lasciato bloccato nella fase 4. Lo script fixperms.sh parte come root —
gli serve, per fare chown — sistema la proprietà, e poi cede il posto all'utente non
privilegiato con exec: da lì in avanti il processo non è più root.

    docker build -q -t "$IMG_ENTRY" -f "$HERE/Dockerfile.entrypoint" "$HERE" >/dev/null
    entry_uid=$(docker run --rm -e "TARGET_UID=$HOST_UID" -v "$HOSTDIR:/data" "$IMG_ENTRY" 'id -u; echo done > /data/state/written' | head -1)
    entry_owner=$(stat -c '%u' "$ROOTDIR/written" 2>/dev/null || echo NONE)
    rm -rf "$ROOTDIR" 2>/dev/null && after_cure=REMOVED || after_cure=DENIED

Su una base completa questo passaggio si scrive con gosu (mondo Debian) o su-exec
(mondo Alpine); qui la base è busybox e il gesto è lo stesso: exec sostituisce il
processo invece di restargli sopra, così il comando resta PID 1 come nel capitolo
10. Alla fine l'albero che prima era bloccato si rimuove senza privilegi.

Quando i sei TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- ipermessi.sh riproduce il mismatch: un UID che non possiede la cartella è respinto
  (TODO 1).
- Risolve facendo girare il container con l'UID proprietario (TODO 2).
- Verifica dall'host la proprietà del file creato (TODO 3).
- Riproduce l'albero lasciato da root e la rimozione negata (TODO 4).
- Cura con USER dichiarato nell'immagine (TODO 5).
- Cura con l'entrypoint che sistema e cede (TODO 6).
- run.sh stampa OK 1..6 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — mismatch: il container con un UID che non possiede la cartella non
  scrive (risultato DENIED).
- **OK 2** — cura: lo stesso container, con l'UID proprietario, scrive (risultato
  WROTE).
- **OK 3** — nessuna traduzione: il file creato dal container è di proprietà, sull'
  host, dello stesso UID con cui girava il container.
- **OK 4** — il problema dei file di root: l'albero creato dal container root
  appartiene a UID 0 sull'host, e il tuo utente non riesce a rimuoverlo.
- **OK 5** — cura con USER: l'immagine che dichiara il tuo UID scrive senza alcun
  flag al lancio, e il file che crea è tuo.
- **OK 6** — cura con l'entrypoint: dopo il chown il processo gira con il tuo UID,
  quello che scrive è tuo, e l'albero che root aveva bloccato ora si rimuove senza
  privilegi.

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

Niente da smontare a mano: i container sono usa-e-getta (--rm), le due immagini
costruite dallo scenario vengono rimosse da un trap, e la cartella condivisa vive in
una directory temporanea che run.sh ripulisce da sé — l'ultimo residuo di root, se
c'è, viene tolto da dentro un container e mai con sudo. L'immagine
base busybox resta in cache (condivisa). Il demone non viene mai riavviato.

## Dove porta

Con questo capitolo la Parte 4 è completa: sai dove tenere i dati, con quale
montaggio e con quali permessi. La **Parte 5** cambia dimensione: non più lo storage
ma la **rete**. Il **capitolo 16** apre i labirinti del networking — come Docker
manipola lo stack di rete di Linux (namespace di rete, veth, bridge) per dare a ogni
container il suo indirizzo. Per il riferimento dei comandi, vedi le appendici del
volume.
