# Cap. 31 — Mettere un tetto

> Esercizio del **Capitolo 31 — Cgroups v2: contabilità e limiti** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Avanzato

## Obiettivi

Al termine di questo laboratorio saprai:

- creare cgroup v2 soltanto dentro una scope utente delegata;
- limitare un carico a mezzo core e leggere il throttling da cpu.stat;
- confinare un allocatore di memoria e osservare l'OOM del solo gruppo;
- confrontare la pressione recuperabile di memory.high con il limite rigido di memory.max.

## Prerequisiti

- Un host Linux con gerarchia cgroup v2 unificata.
- Una sessione systemd utente attiva e systemd-run disponibile.
- Bash, Python 3, timeout e permesso di creare una scope con Delegate=yes.
- Almeno 128 MiB di memoria disponibili per un test breve; il carico resta comunque limitato nel proprio cgroup.

## Consegna

1. Copia la directory start in una directory di lavoro e completa observations.md.
2. Avvia il laboratorio esclusivamente in una scope utente delegata:

       systemd-run --user --scope -p Delegate=yes ./cgroup-lab.sh

   Non creare cgroup direttamente alla radice di /sys/fs/cgroup.
3. Dentro la scope sposta il processo di controllo in un cgroup dedicato, abilita i controller cpu e memory e crea il cgroup labcap31-cpu.
4. Imposta cpu.max a 50000 100000, esegui per tre secondi un solo carico CPU e confronta nr_periods, nr_throttled e throttled_usec prima e dopo.
5. Crea labcap31-high con memory.high a 32 MiB e memory.max a 96 MiB. Allocando 72 MiB, verifica che il carico termini e che il contatore high aumenti.
6. Ripeti lo stesso carico di 72 MiB in labcap31-max, questa volta con memory.max a 48 MiB, memory.high disabilitato e memory.oom.group attivo. Verifica che il carico venga terminato e che oom_kill aumenti.
7. Riporta i contatori in observations.md e spiega perché memory.high rallenta e forza il reclaim, mentre memory.max impedisce di superare il tetto.
8. Rimuovi i cgroup figli e lascia terminare la scope. Verifica che non rimangano processi del laboratorio.

La directory solution contiene una soluzione eseguibile:

    ./solution/run.sh

## Criteri di "fatto"

- [ ] Tutti i cgroup del laboratorio sono figli di una scope utente con delega esplicita.
- [ ] cpu.max rappresenta mezzo core e cpu.stat mostra almeno un evento di throttling.
- [ ] Lo stesso carico da 72 MiB sopravvive a memory.high ma viene terminato da memory.max.
- [ ] memory.events mostra un aumento di high nel primo caso e di oom_kill nel secondo.
- [ ] Il processo di controllo resta fuori dai cgroup limitati.
- [ ] La durata dei carichi è limitata e tutti i cgroup e processi temporanei vengono rimossi.
