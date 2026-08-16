# Cap. 15 — Riempire la memoria e guardare chi cade

> Esercizio del **Capitolo 15 — Allocazione, cache e OOM killer** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- distinguere memoria libera e memoria disponibile quando cresce la page cache;
- osservare che una grande allocazione virtuale non consuma memoria fisica finché le pagine non vengono toccate;
- provocare un OOM confinato e identificare il processo terminato dal kernel;
- verificare i limiti di memoria e l'esito OOM attraverso lo stato del container.

## Prerequisiti

- Un host Linux con Docker installato e accesso al demone.
- La possibilità di eseguire l'immagine python:3.12-alpine, già presente o scaricabile.
- Almeno 250 MiB di spazio temporaneo su disco.

## Consegna

Questo esercizio non va eseguito direttamente sull'host. Lo script crea tre container distinti, tutti con memoria e swap limitati allo stesso valore, mezzo processore, un numero massimo di processi e un timeout. Per avviare l'intera prova:

    solution/run.sh

1. Nel primo container, osserva i valori prima e dopo la scrittura e la sincronizzazione di un file da 120 MiB. /proc/meminfo non è isolato dal cgroup su una normale installazione Docker, quindi la soluzione calcola due grandezze equivalenti entro il limite del laboratorio:

       cgroup free = memory.max - memory.current
       cgroup available estimate = cgroup free + file cache, limitata a memory.max

   Registra quanto calano le due grandezze. La seconda cala molto meno perché include cache di file recuperabile.

2. Nel secondo container, il programma crea una mappatura anonima da 1 GiB senza scriverci. Confronta VmSize e memory.current prima e dopo. VmSize aumenta di circa 1 GiB, mentre l'uso fisico del cgroup cambia poco: è l'overcommit osservato prima del primo accesso alle pagine.

3. Nel terzo container, un allocatore tocca blocchi da 8 MiB sotto un limite di 128 MiB senza swap. Lo script imposta un valore oom-score-adj positivo, stampa i log del processo e verifica:

       docker inspect --format 'oom={{.State.OOMKilled}} exit={{.State.ExitCode}}' labcap15-oom

   L'esito atteso è oom=true ed exit=137. Questo identifica come vittima il processo nel container. Non usare dmesg come requisito: in molti ambienti i messaggi del kernel non sono leggibili da utenti non privilegiati. I log del container mostrano l'ultima allocazione completata, mentre lo stato OOMKilled attesta la decisione del kernel.

4. Trascrivi misure e conclusioni in start/observations.md. Se il demone non è accessibile, annota il salto e non eseguire nessuno dei tre programmi direttamente sull'host.

## Criteri di "fatto"

- [ ] Hai confrontato memoria libera e stima della memoria disponibile prima e dopo aver riempito la page cache.
- [ ] Hai mostrato che la memoria virtuale cresce molto più della memoria fisica per un'allocazione non toccata.
- [ ] Hai ottenuto OOMKilled=true ed exit code 137 per il solo container OOM.
- [ ] Hai letto i log dell'allocatore fino al blocco che precede la terminazione.
- [ ] Hai verificato che memory e memory-swap coincidano per ogni container.
- [ ] Nessun processo o container del laboratorio resta attivo al termine.
