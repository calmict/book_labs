# Capitolo 3 — Limitare CPU e RAM a mano

**Livello:** Fondamentale

I namespace decidono che cosa un processo vede; ora osservi direttamente i contatori che decidono quanto può consumare.

## Obiettivi

- Creare un cgroup v2 e leggerne i controller disponibili (3.1, 3.2).
- Osservare il diverso destino di CPU e memoria: throttling e OOM kill (3.3).
- Verificare il limite al numero di processi e collegare i controller ai limits di Kubernetes (3.3, 3.4).

## Prerequisiti

- Linux con cgroup v2 e una sessione utente systemd che deleghi i controller memory e pids.
- systemd-run e Python 3. Nessun privilegio root e nessun cluster Kubernetes.
- Per provare personalmente cpu.max serve invece un ambiente Linux usa-e-getta con il controller cpu disponibile; run.sh segnala il passo senza tentarlo quando cpu non è delegato.
- Capitolo 2 completato.

## Lo scenario

In start/ trovi cage.sh, valido ma incompleto. Le tre lacune creano e interrogano un cgroup delegato, impongono un tetto alla memoria e limitano i processi.

    cd kubernetes/ed1/cap03/start

### Fase 1 — La gabbia e i suoi controller (3.1, 3.2 — TODO 1)

La directory lab-cap03 è un vero cgroup. Leggi cgroup.controllers e verifica che memory e pids siano disponibili nel sottoalbero utente.

### Fase 2 — Il tempo CPU (3.3)

Il limite didattico resta cpu.max uguale a 20000 100000, cioè il 20 per cento di un core. Il controller cpu non è delegato alla sessione utente di questa macchina: run.sh conserva il passo come unico SKIP e riporta la misura che dimostra perché non sarebbe una prova valida.

### Fase 3 — Il tetto di memoria (3.3 — TODO 2)

Usa uno scope utente con MemoryMax=20M e MemorySwapMax=0 per lanciare un processo che tenta di allocare 200 MiB. Deve morire con exit 137. Ripeti senza limite: la stampa ALLOCATED è la contro-prova che fa mordere il cancello.

### Fase 4 — Il buttafuori dei fork (3.3 — TODO 3)

Usa TasksMax=3 e avvia più processi di quanti lo scope possa accettare. Bash deve riferire Resource temporarily unavailable.

Esegui quindi il controllo completo:

    cd ../solution
    bash run.sh

## Criteri di "fatto"

- Il cgroup delegato viene creato e dichiara memory e pids.
- Il processo limitato muore con exit 137, mentre la stessa allocazione senza limite riesce.
- TasksMax respinge realmente un fork oltre il limite.
- run.sh stampa OK 1, SKIP 2, OK 3, OK 4 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 crea il cgroup e legge i controller realmente delegati.
- SKIP 2 documenta il throttling CPU non verificabile nello user slice e la misura che lo dimostra.
- OK 3 confronta la morte con MemoryMax con l'allocazione riuscita senza limite.
- OK 4 verifica l'errore di fork prodotto da TasksMax=3.

## Domande di riflessione

**a.** Perché la CPU rallenta mentre la memoria può uccidere?

**b.** Come diventano cpu.max e memory.max i limits di un Pod?

**c.** Che cosa raccontano nr_throttled, oom_kill e pids.max durante il troubleshooting?

## Pulizia

run.sh usa scope raccolti automaticamente e rimuove il cgroup lab-cap03 creato nel sottoalbero utente. Non restano processi o cgroup del laboratorio.

## Dove porta

Il capitolo 4 combina namespace e cgroup nel runtime che Kubernetes usa per eseguire i container.
