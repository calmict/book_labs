# Capitolo 23 — Re nella propria stanza

**Livello:** Cloud Architect

Apriamo la Parte 7 — sicurezza e day-2 — dalla domanda che sta sotto a tutto: chi è
root, davvero? Nel Docker classico il demone gira come root sull'host, e chi può
parlargli (il gruppo docker) è root a tutti gli effetti. Un container che gira come
root è root sull'host per i file che monta, e un'evasione è un'evasione da root. La
modalità rootless ribalta il quadro usando lo USER namespace del capitolo 2: il
demone e i container girano dentro un namespace dove sei «root», ma quel root è
mappato a un utente non privilegiato sull'host. Sei re nella tua stanza, un utente
qualunque fuori. In questo laboratorio tocchi con mano la mappatura: dentro sei uid
0 con tutte le capability, fuori sei il tuo utente, e quel «root» non può fare nulla
di privilegiato sull'host.

## Obiettivi

- Entrare in uno USER namespace che ti mappa a root e vedere che dentro sei uid 0
  (23.2).
- Verificare che quel root è mappato al tuo utente reale, non privilegiato, sull'
  host (23.3).
- Constatare che quel «root» non può toccare i file di root dell'host — è potente
  solo dentro il namespace (23.3).
- Dimostrare che chi parla al demone Docker rootful legge il filesystem dell'host
  come uid 0, pur essendo un utente host non privilegiato (23.1).
- Isolare la causa con lo stesso mount eseguito come UID non privilegiato (23.4).
- Capire perché questo modello riduce il raggio d'azione di un'evasione (23.4).

## Prerequisiti

- Un Linux con gli **user namespace non privilegiati abilitati** (default sulle
  distribuzioni moderne; è quanto usa Docker rootless). Serve il comando unshare
  (util-linux). Nessun sudo.
- Docker installato, demone raggiungibile e appartenenza al gruppo docker, come
  descritto in ../../SETUP.md. Esegui l'esercizio da utente non privilegiato, mai
  da root: il confronto dipende proprio da questa condizione.
- Il capitolo 2 (i namespace, tra cui lo USER namespace) e il capitolo 12
  (container non-root): qui vedi cosa c'è sotto.

## Lo scenario

In start/ trovi rootless.sh: uno script che dovrebbe entrare in uno user namespace e
misurare la mappatura degli UID e i limiti di quel «root», ma le cinque misure chiave
mancano. Colmi cinque lacune (TODO 1..5). Le prime tre usano solo unshare; le ultime
due interrogano il demone Docker senza riconfigurarlo.

La dimostrazione è deliberatamente innocua: monta / in /host in sola lettura, non
scrive nulla sull'host e non legge alcun file di credenziali. Il percorso di prova
lo sceglie lo script: il primo fra /root e /var/lib/docker che il tuo utente non
riesce ad aprire. Di quel percorso si verifica soltanto se si apre, senza elencarne
né stamparne il contenuto.

Prepara l'ambiente:

    cd docker/ed1/cap23/start

### Fase 1 — Root nella propria stanza (23.2 — TODO 1)

Apri start/rootless.sh e completa il **TODO 1**: entra in uno user namespace che
mappa il tuo utente a root, e leggi l'uid. Dentro sei 0 — «root».

    inner_uid=$(unshare --user --map-root-user id -u)

### Fase 2 — Ma quale root? (23.3 — TODO 2)

Completa il **TODO 2**: da dentro, crea un file «da root», poi guarda dall'host di
chi è. Non è di root: è del tuo utente reale. Il root del namespace è mappato al tuo
UID non privilegiato.

    unshare --user --map-root-user sh -c "touch '$OUT/asroot'"
    owner_uid=$(stat -c '%u' "$OUT/asroot")

### Fase 3 — Potente solo dentro (23.3 — TODO 3)

Completa il **TODO 3**: prova, «da root» nel namespace, a scrivere in un percorso di
root dell'host (/etc). Non ci riesce: le capability valgono dentro il namespace, non
sull'host.

    host_write=$(unshare --user --map-root-user sh -c 'touch /etc/rootless-probe 2>/dev/null && echo YES || echo NO')

### Fase 4 — Dal gruppo docker al filesystem dell'host (23.1 — TODO 4)

Completa il **TODO 4**: prova ad aprire il percorso di prova da utente — il permesso
è negato, ed è questa la controprova senza la quale il resto non dimostrerebbe nulla.
Poi chiedi al demone un container con / montata in /host in sola lettura: dentro sei
uid 0, e lo stesso percorso si apre. Leggi anche proprietario e permessi, che dicono
perché prima era chiuso.

    direct_read=$(ls -A "$probe" >/dev/null 2>&1 && echo YES || echo NO)
    root_probe=$(docker run --rm --name "$ROOT_CONTAINER" -v /:/host:ro "$IMAGE" sh -c 'printf "%s:%s:%s:" "$(id -u)" "$(stat -c %u "/host$1")" "$(stat -c %a "/host$1")"; ls -A "/host$1" >/dev/null 2>&1 && echo YES || echo NO' sh "$probe")

### Fase 5 — Non è il mount, è chi chiedi di essere (23.4 — TODO 5)

Completa il **TODO 5**: ripeti con la stessa immagine e lo stesso mount in sola
lettura, ma passa --user con i tuoi UID:GID non privilegiati. Il percorso torna
chiuso. Il mount espone il filesystem; il potere di attraversarlo viene dall'uid 0
che hai chiesto al demone. Nel rootless quell'uid 0 è rimappato altrove, esattamente
come nelle Fasi 1-3.

    user_read=$(docker run --rm --name "$USER_CONTAINER" --user "$outer_uid:$outer_gid" -v /:/host:ro "$IMAGE" sh -c 'ls -A "/host$1" >/dev/null 2>&1 && echo YES || echo NO' sh "$probe")

Quando i cinque TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- rootless.sh legge l'uid dentro lo user namespace (TODO 1).
- Legge il proprietario, sull'host, di un file creato «da root» dentro (TODO 2).
- Verifica se quel «root» può scrivere in /etc dell'host (TODO 3).
- Contrappone il diniego diretto all'accesso tramite il demone come uid 0, con il
  filesystem dell'host montato in sola lettura (TODO 4).
- Ripete lo stesso mount come UID non privilegiato e ottiene di nuovo il diniego
  (TODO 5).
- run.sh stampa OK 1..5 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — dentro lo user namespace sei uid 0: «root».
- **OK 2** — quel root è mappato al tuo utente reale (non privilegiato): il file
  creato «da root» è di proprietà del tuo UID sull'host, che non è 0.
- **OK 3** — quel «root» non può scrivere nei file di root dell'host: è potente solo
  dentro il namespace.
- **OK 4** — l'utente host non apre il percorso di prova, mentre il container uid 0
  richiesto al demone lo apre dal mount in sola lettura; proprietario e permessi del
  percorso, stampati, dicono perché la controprova regge.
- **OK 5** — la stessa immagine e lo stesso mount, eseguiti con l'UID non
  privilegiato, restano fuori: la differenza è chi il demone esegue.

## Domande di riflessione

**a.** Nel Docker rootful il demone gira come root e il socket è la sua porta: perché
appartenere al gruppo docker equivale a essere root sull'host (l'hai già incrociato
nel capitolo 5)? Cosa può fare, concretamente, chi scrive su quel socket?

**b.** La modalità rootless usa lo USER namespace del capitolo 2 per rimappare gli
UID: root nel container (0) diventa un subuid non privilegiato sull'host. Cosa
significa che le capability sono «namespaced» — perché dentro vedi CapEff pieno ma
sull'host quel root è impotente? Come si lega ai file montati (capitolo 15)?

**c.** Perché il rootless riduce il raggio d'azione di un'evasione: un processo che
scappa dal container si ritrova a essere un utente non privilegiato, non root
sull'host. Quali sono i limiti pratici del rootless (le porte sotto 1024, alcune
funzionalità che richiedono privilegi reali) e quando li accetti?

## Pulizia

Niente da smontare a mano: run.sh ripulisce la cartella temporanea e i container
cap23 anche in caso di errore; unshare non lascia processi né namespace dopo
l'uscita. I mount sono in sola lettura e scompaiono con i container. Il demone non
viene riconfigurato.

## Dove porta

Hai visto il modello dei privilegi dal basso. Il **capitolo 24** resta sulla
sicurezza ma cambia leva: non chi sei, ma cosa puoi fare — le capability che si
concedono o si tolgono a un container, e i filtri seccomp e AppArmor/SELinux che
restringono le syscall e gli accessi. Per il riferimento, vedi le appendici del
volume.
