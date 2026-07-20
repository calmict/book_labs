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
- Capire perché questo modello riduce il raggio d'azione di un'evasione (23.4).

## Prerequisiti

- Un Linux con gli **user namespace non privilegiati abilitati** (default sulle
  distribuzioni moderne; è quanto usa Docker rootless). Serve il comando unshare
  (util-linux). Nessun sudo, nessun Docker: questo capitolo lavora sul meccanismo
  del kernel sotto il rootless.
- Il capitolo 2 (i namespace, tra cui lo USER namespace) e il capitolo 12
  (container non-root): qui vedi cosa c'è sotto.

## Lo scenario

In start/ trovi irootless.sh: uno script che dovrebbe entrare in uno user namespace e
misurare la mappatura degli UID e i limiti di quel «root», ma le tre misure chiave
mancano. Colmi tre lacune (TODO 1..3). Nessun privilegio, nessun demone toccato: solo
unshare, che gira da utente normale.

Prepara l'ambiente:

    cd docker/ed1/cap23/start

### Fase 1 — Root nella propria stanza (23.2 — TODO 1)

Apri start/irootless.sh e completa il **TODO 1**: entra in uno user namespace che
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

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- irootless.sh legge l'uid dentro lo user namespace (TODO 1).
- Legge il proprietario, sull'host, di un file creato «da root» dentro (TODO 2).
- Verifica se quel «root» può scrivere in /etc dell'host (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — dentro lo user namespace sei uid 0: «root».
- **OK 2** — quel root è mappato al tuo utente reale (non privilegiato): il file
  creato «da root» è di proprietà del tuo UID sull'host, che non è 0.
- **OK 3** — quel «root» non può scrivere nei file di root dell'host: è potente solo
  dentro il namespace.

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

Niente da smontare a mano: lo script lavora in una cartella temporanea che run.sh
ripulisce da sé; unshare non lascia processi né namespace dopo l'uscita. Nessun
demone toccato, nessun privilegio richiesto.

## Dove porta

Hai visto il modello dei privilegi dal basso. Il **capitolo 24** resta sulla
sicurezza ma cambia leva: non chi sei, ma cosa puoi fare — le capability che si
concedono o si tolgono a un container, e i filtri seccomp e AppArmor/SELinux che
restringono le syscall e gli accessi. Per il riferimento, vedi le appendici del
volume.
