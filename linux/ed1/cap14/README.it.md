# Cap. 14 — Provocare i fault e guardarli accadere

> Esercizio del **Capitolo 14 — Paging, page fault e swap** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- distinguere fault minori e maggiori misurandoli su due letture dello stesso file;
- osservare il copy-on-write creare copie private una pagina alla volta dopo fork;
- riconoscere un principio di thrashing dalle scansioni, dai refault e dalla pressione sulla memoria;
- confinare un esperimento di pressione della memoria in un cgroup con risorse limitate.

## Prerequisiti

- Un host Linux con compilatore C, Bash e /usr/bin/time.
- Docker per il solo esperimento di pressione della memoria.
- Permesso di usare il demone Docker.
- Circa 100 MiB liberi per i file temporanei del laboratorio.

## Consegna

1. Compila fault-stats.c, prepara un file da 64 MiB e leggilo una pagina alla volta. Il comando prepare sincronizza il file e chiede al kernel di espellerne le pagine dalla cache, così la prima misura ha buone probabilità di richiedere I/O reale:

       gcc -O2 -Wall -Wextra solution/fault-stats.c -o /tmp/labcap14-fault-stats
       /tmp/labcap14-fault-stats prepare /tmp/labcap14-pages.bin 64
       /usr/bin/time -v /tmp/labcap14-fault-stats read /tmp/labcap14-pages.bin
       /usr/bin/time -v /tmp/labcap14-fault-stats read /tmp/labcap14-pages.bin

   Confronta Minor page faults e Major page faults nelle due esecuzioni. La prima lettura porta le pagine nella page cache; la seconda riusa i dati già residenti. Il numero esatto dipende dal filesystem e dal read-ahead del kernel.

2. Compila ed esegui cow-pages.c. Il processo padre inizializza le pagine prima di fork; il figlio ne modifica una alla volta e stampa l'aumento cumulativo dei fault minori:

       gcc -O2 -Wall -Wextra solution/cow-pages.c -o /tmp/labcap14-cow-pages
       /tmp/labcap14-cow-pages 16

   Spiega perché la scrittura causa fault minori pur senza leggere nulla dal disco.

3. Esegui il carico breve esclusivamente nel container limitato. Lo script usa 96 MiB di memoria, non può superare mezzo processore e viene interrotto dopo 20 secondi:

       solution/run.sh

   Nella sezione relativa alla pressione confronta pgscan, pgsteal, workingset_refault_file e il valore some di memory.pressure prima e dopo il carico. Incrementi ripetuti, memoria vicina al limite e tempo speso in stall sono i sintomi di un working set che non resta residente. Se Docker non è accessibile, non sostituire mai questo passo con un carico equivalente sull'host: annota che la prova è stata saltata.

4. Riporta misure e spiegazioni in start/observations.md. Cancella gli eventuali file temporanei creati eseguendo i comandi manualmente.

## Criteri di "fatto"

- [ ] Hai registrato fault minori e maggiori della prima e della seconda lettura dello stesso file.
- [ ] Hai osservato l'aumento dei fault minori mentre il figlio modifica pagine condivise dopo fork.
- [ ] Hai spiegato il legame tra copy-on-write e fault minori.
- [ ] Hai eseguito la pressione della memoria solo in un container con limiti espliciti e timeout, oppure hai documentato perché il demone non era accessibile.
- [ ] Hai confrontato almeno due metriche tra scansioni, refault e pressione della memoria.
- [ ] Al termine non restano container o processi del laboratorio.
