# Capitolo 14 — Tre modi di stivare

**Livello:** Intermedio

Nel capitolo 13 hai visto che i dati vanno tenuti a terra, non nella stiva del
container. Ma «a terra» ha tre indirizzi diversi, e sceglierli male costa caro. Il
volume è il magazzino del porto: lo gestisce il demone, è portabile e fatto per i
dati. Il bind mount è un molo condiviso con l'host: monti una cartella della tua
macchina dentro il container, e ciò che scrivi si vede da entrambe le parti — comodo
in sviluppo, delicato coi permessi. Il tmpfs è l'armadietto veloce di bordo: vive in
memoria, non tocca il disco, e si svuota all'arrivo. In questo laboratorio li usi
tutti e tre e ne verifichi il tratto che li distingue.

## Obiettivi

- Usare un bind mount: una cartella dell'host montata dentro, con scrittura
  bidirezionale (14.2).
- Usare un volume gestito dal demone, persistente tra i container (14.1).
- Usare un tmpfs: montaggio in memoria, non persistito e mai su disco (14.3).
- Riconoscere quale scegliere e perché (14.4).

## Prerequisiti

- Un Linux con Docker Engine attivo (vedi SETUP.md), nativo (il bind mount monta un
  percorso reale dell'host). Il tuo utente deve poter usare Docker.
- Il capitolo 13 (il ciclo di vita dei dati): qui vedi i modi concreti di tenerli.

## Lo scenario

In start/ trovi imontaggi.sh: uno script che dovrebbe mettere a confronto i tre
montaggi, ma le tre operazioni chiave mancano. Colmi tre lacune (TODO 1..3).
Container usa-e-getta (--rm), un volume con nome unico e una cartella temporanea:
il demone condiviso non si tocca.

Prepara l'ambiente:

    cd docker/ed1/cap14/start

### Fase 1 — Il molo condiviso: bind mount (14.2 — TODO 1)

Apri start/imontaggi.sh e completa il **TODO 1**: monta una cartella dell'host su
/mnt e scrivici un file dal container. Il tratto del bind è la bidirezionalità: il
file compare sull'host, allo stesso percorso che hai scelto.

    docker run --rm -v "$HOSTDIR:/mnt" busybox sh -c 'echo frombind > /mnt/b.txt'

### Fase 2 — Il magazzino del porto: volume (14.1 — TODO 2)

Completa il **TODO 2**: dopo aver scritto in un volume con nome, rileggilo da un
container nuovo. Il tratto del volume è la persistenza gestita: i dati vivono
nell'area del demone, non in un percorso dell'host che hai scelto tu.

    vol_persist=$(docker run --rm -v "$VOL:/data" busybox sh -c 'cat /data/v.txt 2>/dev/null || echo GONE')

### Fase 3 — L'armadietto di bordo: tmpfs (14.3 — TODO 3)

Completa il **TODO 3**: monta un tmpfs su /cache, scrivici, e riporta il tipo di
montaggio letto da /proc/mounts. Il tratto del tmpfs è che vive in memoria: non
persiste e non tocca né il disco né l'host.

    tmpfs_type=$(docker run --rm --tmpfs /cache busybox sh -c 'echo x > /cache/t.txt; grep -q " /cache tmpfs " /proc/mounts && echo TMPFS || echo other')

Quando i tre TODO sono colmati, esegui il test:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- imontaggi.sh scrive tramite un bind mount su una cartella dell'host (TODO 1).
- Rilegge da un container nuovo un file scritto in un volume (TODO 2).
- Monta un tmpfs e ne riporta il tipo (TODO 3).
- run.sh stampa OK 1..3 e ALL CHECKS PASSED.

## Come viene verificato

solution/run.sh esegue lo scenario e verifica, punto per punto:

- **OK 1** — bind mount: il file scritto dal container compare sull'host, al
  percorso montato (scrittura bidirezionale con l'host).
- **OK 2** — volume: il file scritto nel volume viene riletto da un container nuovo
  (persistenza gestita dal demone).
- **OK 3** — tmpfs: il montaggio su /cache è di tipo tmpfs (in memoria), quindi non
  persistito e mai su disco.

## Domande di riflessione

**a.** Bind mount e volume persistono entrambi, ma dove vivono i dati e chi decide
il percorso? Perché un bind lega tutto a una cartella dell'host — con i suoi
permessi e il rischio di sovrascrivere ciò che c'è già al mount point — mentre un
volume è portabile e gestito dal demone (creazione, backup, rimozione con docker)?

**b.** Un tmpfs vive in memoria e sparisce allo stop del container. Perché questo lo
rende adatto a dati temporanei o sensibili (che non vuoi lasciare su disco) e a
scenari dove conta la velocità? Cosa succede al suo contenuto quando il container si
ferma, e perché non compare in nessun volume né sull'host?

**c.** Regola pratica: in sviluppo monti il codice con un bind (modifiche live), in
produzione tieni i dati in un volume, e usi tmpfs per cache o segreti effimeri.
Perché montare il codice con un bind in produzione è fragile, e come si lega la
scelta ai permessi UID/GID sui volumi condivisi del capitolo 15?

## Pulizia

Niente da smontare a mano: i container sono usa-e-getta (--rm), il volume con nome è
rimosso dallo script (docker volume rm, più un trap di sicurezza) e la cartella del
bind vive in una directory temporanea che run.sh ripulisce da sé. Il tmpfs sparisce
con il suo container. L'immagine base busybox resta in cache. Il demone non viene
mai riavviato.

## Dove porta

Sai dove mettere i dati e con quale montaggio. Resta un dettaglio che fa inciampare
tutti quando si condivide un volume o un bind: i **permessi**. Il **capitolo 15**
affronta UID e GID sui volumi condivisi — perché un container non-root (capitolo 12)
a volte non riesce a scrivere in un volume, e come si allineano gli identificativi.
Per il riferimento dei comandi, vedi le appendici del volume.
