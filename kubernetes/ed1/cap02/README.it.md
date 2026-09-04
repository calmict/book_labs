# Capitolo 2 — Un container a mano, senza Docker

**Livello:** Fondamentale

Dopo le due viste del capitolo 1, costruisci tu l'illusione usando soltanto gli strumenti del kernel Linux.

## Obiettivi

- Creare namespace PID, mount, UTS, IPC, NET e USER con unshare (2.2, 2.3).
- Ottenere PID 1, hostname privato e rete isolata (2.2, 2.4).
- Confrontare gli inode esposti da /proc/[pid]/ns (2.5).

## Prerequisiti

- Linux con unshare, sh e permesso di creare user namespace non privilegiati.
- Capitolo 1 completato. Non servono sudo, Docker o un cluster Kubernetes.

## Lo scenario

In start/ trovi handmade.sh: scarica un mini-rootfs Alpine e apre soltanto un USER namespace. Completa tre lacune perché unshare e chroot lo trasformino in un piccolo container rootless.

    cd kubernetes/ed1/cap02/start

### Fase 1 — Le pareti (2.2, 2.3 — TODO 1)

Aggiungi i namespace PID, mount, UTS, IPC e NET e rimonta /proc nella nuova vista.

### Fase 2 — Le prove interne (2.2, 2.4, 2.5 — TODO 2)

Imposta l'hostname e registra PID, interfacce e inode dei namespace dall'interno.

### Fase 3 — Il confronto (2.5 — TODO 3)

Registra gli stessi inode e l'hostname dall'host, quindi esegui:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- La shell è PID 1, l'hostname è privato e la rete mostra solo loopback.
- Gli inode pid, uts, net e user differiscono da quelli dell'host.
- run.sh stampa OK 1..5 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 verifica PID 1; OK 2 l'isolamento UTS; OK 3 la rete privata.
- OK 4 confronta gli inode dei quattro namespace.
- OK 5 rimuove il PID namespace e dimostra che la shell non è più PID 1.

## Domande di riflessione

**a.** In che senso unshare svolge il lavoro concettuale di docker run?

**b.** Che cosa offre chroot, e che cosa manca ancora rispetto a un runtime completo?

**c.** Perché --fork è necessario insieme a --pid?

## Pulizia

I processi terminano con lo script; run.sh elimina la cartella temporanea.

## Dove porta

Il capitolo 3 aggiunge ai confini di visibilità i limiti di consumo dei cgroup.
