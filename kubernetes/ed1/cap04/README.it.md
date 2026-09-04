# Capitolo 4 — Smonta un'immagine a mano

**Livello:** Fondamentale

Dopo namespaces e cgroup manca l'ultimo pezzo dell'anatomia: il filesystem. In questo laboratorio
apri un'immagine, segui i riferimenti tra i suoi oggetti e osservi ciò che separa il root del container
dal root dell'host.

## Obiettivi

- Riconoscere manifest, config e layer di un'immagine OCI (4.2).
- Osservare copy-up, whiteout e immutabilità del layer inferiore con OverlayFS (4.1).
- Confrontare capabilities e kernel dentro e fuori dal container (4.3, 4.4).

## Prerequisiti

- Un host Linux con Docker, jq, tar, sha256sum, mount e unshare.
- Possibilità di creare user namespace non privilegiati; non servono sudo né mount sull'host.
- Circa 30 MB di spazio temporaneo.

## Lo scenario

In start/image-lab.sh trovi uno script valido ma incompleto. Completa tre lacune: seguire il manifest,
costruire la vista OverlayFS e raccogliere le prove sul confine tra container e host.

    cd kubernetes/ed1/cap04/start

### Fase 1 — Segui gli indirizzi (4.2 — TODO 1)

Leggi image/manifest.json con jq e salva in image.env i percorsi Config e del primo elemento Layers.
Non scegliere i blob dal nome: è il manifest a stabilire la catena.

### Fase 2 — Scrivi senza cambiare l'immagine (4.1 — TODO 2)

Estrai il layer, poi dentro unshare -Urm monta un OverlayFS con lowerdir, upperdir e workdir. Modifica
etc/motd e cancella etc/hostname nella vista merged; registra checksum e presenza dei file prima e dopo.

### Fase 3 — Root con poteri limitati (4.3, 4.4 — TODO 3)

Confronta CapEff di PID 1 con quello del processo nel container, tenta date -s nel container e confronta
uname -r. Registra i risultati in isolation.env, poi esegui:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- I tre TODO sono completati e i file prodotti identificano oggetti reali.
- Il layer inferiore resta invariato dopo modifica e cancellazione nella vista merged.
- Il tentativo di cambiare l'ora è rifiutato e il kernel coincide.
- run.sh stampa OK 1..5 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 segue manifest, config e layer e valida le sezioni config e rootfs.
- OK 2 controlla copy-up, cancellazione e immutabilità del layer inferiore.
- OK 3 controlla capabilities diverse e rifiuto di date -s.
- OK 4 confronta le versioni del kernel.
- OK 5 è il cancello: senza upperdir la modifica deve fallire.

## Domande di riflessione

**a.** Che cosa contiene davvero un'immagine OCI e come si segue la catena manifest, config e layer?

**b.** Dove finiscono modifica e cancellazione, e perché questo rende usa-e-getta il container layer?

**c.** Perché root nel container non può cambiare l'ora, e che relazione ha con il kernel condiviso?

## Pulizia

run.sh usa una directory temporanea e il mount vive in uno user namespace che termina da solo. Il trap
rimuove tutti i file; non restano container né mount sull'host.

## Dove porta

Hai aperto il pacchetto e riconosciuto i meccanismi che lo isolano. Il capitolo 5 segue chi assembla
questi pezzi: containerd prepara il bundle OCI e runc crea il processo.
