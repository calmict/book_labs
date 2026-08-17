# Cap. 32 — Il tuo container, dalla prima riga

> Esercizio del **Capitolo 32 — Un container a mano, senza Docker** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Avanzato

## Obiettivi

Al termine di questo laboratorio saprai:

- costruire un filesystem di base in una directory temporanea;
- combinare namespace user, PID, rete, UTS, mount e IPC senza privilegi sull'host;
- sostituire la radice con pivot_root e montare proc soltanto nella nuova radice;
- applicare limiti CPU e memoria tramite un cgroup v2 delegato;
- collegare il container a un lato host isolato con una coppia veth;
- provocare in modo controllato saturazione CPU e OOM e verificare l'invisibilità dei processi host.

## Prerequisiti

- Un host Linux con namespace utente non privilegiati e gerarchia cgroup v2 unificata.
- Una sessione systemd utente attiva che consenta scope con Delegate=yes.
- Bash, util-linux, iproute2, procps, debootstrap e timeout.
- Accesso alla rete per costruire un filesystem Debian minimale e circa 500 MiB di spazio temporaneo.

## Consegna

1. Copia la directory start in una directory di lavoro e completa observations.md.
2. Crea una directory temporanea e costruisci al suo interno un filesystem minimale con debootstrap. Non riusare una radice esistente dell'host.
3. Avvia il controllo del laboratorio in una scope utente con delega esplicita. Crea il cgroup labcap32-container dentro la scope, imposta cpu.max a 50000 100000, memory.max a 96 MiB, memory.swap.max a zero e memory.oom.group a uno.
4. Costruisci prima un namespace di rete esterno non privilegiato che rappresenti il lato host del laboratorio. Da lì avvia il container con il comando completo:

       unshare --user --map-root-user --pid --net --uts --mount --ipc --propagation private --fork ./container-init.sh

   Il lato host resta a sua volta isolato dalla rete reale: questa doppia barriera consente di configurare la veth senza privilegi e senza modificare interfacce o instradamento dell'host reale.
5. Collega labcap32-host a labcap32-guest con una coppia veth. Assegna 10.200.32.1/24 al lato host isolato e 10.200.32.2/24 al container, attiva loopback e verifica il collegamento con ping.
6. Nel nuovo namespace mount esegui un bind mount della radice, usa pivot_root, smonta la vecchia radice e soltanto dopo monta proc dentro la nuova radice.
7. Nel container verifica che la shell sia PID 1, che /.oldroot non esista e che un processo sentinella labcap32-host-sentinel avviato fuori dal namespace PID non compaia in ps.
8. Satura la CPU per tre secondi sotto timeout e osserva l'aumento di nr_throttled. Infine scrivi 160 MiB su un tmpfs con memory.max a 96 MiB: il gruppo deve subire OOM senza coinvolgere il processo di controllo.
9. Registra contatori e osservazioni, poi rimuovi veth, processi, cgroup, filesystem e directory temporanee.

La directory solution contiene una soluzione eseguibile:

    ./solution/run.sh

## Criteri di "fatto"

- [ ] Il filesystem è stato costruito in una directory temporanea e pivot_root ha reso irraggiungibile la vecchia radice.
- [ ] Il container usa tutti i namespace richiesti e proc è stato montato soltanto dopo pivot_root.
- [ ] La coppia labcap32-host e labcap32-guest collega il container al lato host isolato senza modificare la rete reale.
- [ ] Il processo sentinella dell'host non è visibile dal container.
- [ ] cpu.stat mostra throttling e memory.events mostra un OOM kill nel cgroup limitato.
- [ ] Ogni carico è breve e limitato; nessun processo, cgroup, mount, interfaccia o file temporaneo rimane al termine.
