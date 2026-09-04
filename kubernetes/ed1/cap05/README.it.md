# Capitolo 5 — Risali la catena dei runtime

**Livello:** Fondamentale

Hai costruito a mano i pezzi di un container; ora segui chi li assembla. Parti dal processo vivo,
risali fino allo shim, interroghi containerd e infine consegni un bundle direttamente a runc.

## Obiettivi

- Risalire la catena reale tra workload, shim e init (5.2).
- Interrogare containerd senza passare dalla CLI Docker (5.1, 5.3).
- Leggere namespaces, cgroup, capabilities e rootfs nel bundle OCI (5.3).
- Avviare un processo con il solo runc (5.2, 5.3).

## Prerequisiti

- Un host Linux con Docker, runc, ctr, jq, ps, awk e tar.
- Accesso al demone Docker; non servono sudo né container privilegiati.
- L'immagine docker:29-dind per il helper automatico: se il socket containerd non è leggibile
  direttamente, viene montato nel helper insieme alla directory dei task in sola lettura.

## Lo scenario

In start/runtime-lab.sh trovi la sequenza già predisposta ma con tre prove mancanti. Completale senza
cambiare il workload sleep infinity né sostituire la catena reale con una simulazione.

    cd kubernetes/ed1/cap05/start

### Fase 1 — Dal processo a init (5.2 — TODO 1)

Ottieni il PID con docker inspect e segui il quarto campo di proc/PID/stat. Scrivi ogni coppia PID e
nome in parent-chain.txt: il passaggio attraverso containerd-shim è la prova cercata.

### Fase 2 — Scavalca Docker (5.1, 5.3 — TODO 2)

Usa ctr nel namespace logico moby e salva l'elenco dei task. Copia anche il config.json vivo. Se i
permessi dell'host negano l'accesso diretto, usa il helper non privilegiato descritto nei Prerequisiti;
la directory dei task deve restare in sola lettura.

### Fase 3 — Solo runc (5.3 — TODO 3)

Esporta il rootfs, genera una spec rootless e sostituisci la shell interattiva con un comando batch che
registri PID e hostname. Avvia il bundle con runc, poi esegui:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- La catena mostra workload, containerd-shim e poi init.
- ctr elenca lo stesso ID e config.json contiene gli ingredienti dei capitoli 2-4.
- Il processo avviato dal solo runc si vede come PID 1.
- run.sh stampa OK 1..5 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 controlla la catena dei padri reale.
- OK 2 confronta l'ID Docker con il task visto da ctr.
- OK 3 legge namespaces, resources, capabilities e root nel bundle vivo.
- OK 4 esegue il bundle rootless con runc e verifica PID 1.
- OK 5 è il cancello: con il processo predefinito della spec manca la prova richiesta.

## Domande di riflessione

**a.** Perché lo shim è il padre diretto e dockerd e containerd non sono antenati del workload?

**b.** Ricostruisci la catena CLI, dockerd, containerd, shim, runc e processo. Che cosa dimostra moby?

**c.** Dove compaiono nel config.json i capitoli 2-4, e che cosa fa runc dopo la creazione?

## Pulizia

Il trap rimuove entrambi i container e la directory temporanea. Il helper termina dopo ogni lettura;
il socket non viene modificato e la directory dei task è montata in sola lettura.

## Dove porta

Runc sa creare un processo isolato, ma non gli costruisce la rete. Il capitolo 6 prende veth e bridge
e cabla a mano il percorso che un runtime prepara per ogni container.
