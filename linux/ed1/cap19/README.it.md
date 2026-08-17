# Cap. 19 — Il dato che credi di aver salvato

> Esercizio del **Capitolo 19 — I filesystem reali e il block layer** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- osservare i dati sporchi presenti nella cache del kernel dopo una write;
- misurare la differenza fra completare una scrittura e richiederne la sincronizzazione;
- sostituire un file senza esporre stati intermedi e rendere durevole anche la nuova voce di directory;
- ricostruire la pila che collega un mount ai dispositivi a blocchi sottostanti.

## Prerequisiti

- Un host Linux con Bash, Python 3, coreutils, util-linux e procfs montato.
- Almeno 200 MiB liberi nella directory dell'esercizio.
- Nessun dato importante nella directory solution/labcap19-work: lo script la ricrea e la elimina.
- Non servono privilegi amministrativi e non si deve scrivere direttamente su alcun dispositivo a blocchi.

## Consegna

1. Leggi il valore Dirty in /proc/meminfo, scrivi un file regolare senza richiedere fsync e rileggi subito il valore. Sincronizza quel solo file e osserva di nuovo Dirty. Ricorda che il contatore è globale all'host e il writeback può procedere mentre misuri.

       awk '/^Dirty:/ {print}' /proc/meminfo
       dd if=/dev/zero of=buffered.bin bs=1M count=64 status=none
       awk '/^Dirty:/ {print}' /proc/meminfo
       sync buffered.bin
       awk '/^Dirty:/ {print}' /proc/meminfo

2. Cronometra due scritture equivalenti su file regolari nella directory dell'esercizio. La prima termina alla chiusura del file; la seconda usa conv=fsync per attendere la sincronizzazione. Ripeti le misure se il sistema è occupato e non interpretare una singola misura come benchmark del dispositivo.

       dd if=/dev/zero of=without-fsync.bin bs=1M count=64 status=none
       dd if=/dev/zero of=with-fsync.bin bs=1M count=64 conv=fsync status=none

3. Implementa una funzione che gestisca anche write parziali: scrivi completamente il contenuto in un file temporaneo nella stessa directory, esegui fsync sul file, chiudilo, sostituisci il nome finale con rename e infine esegui fsync sulla directory.

4. Durante molte sostituzioni, mantieni un lettore concorrente che convalidi ogni versione. La prova deve fallire se osserva un file mancante, troncato o composto da parti di versioni diverse.

5. Non provocare un arresto della macchina. Verifica invece il percorso di sincronizzazione con una copia mediante dd conv=fsync, poi confronta byte e checksum del file sorgente e di quello persistito. Spiega che una prova di recupero dopo un vero crash richiede una macchina virtuale sacrificabile.

6. Usa findmnt per identificare sorgente e tipo del filesystem della directory di lavoro, quindi lsblk per leggere dischi, partizioni e relazioni parentali. Non scrivere mai su tali dispositivi.

7. Registra output e osservazioni in answers.md oppure esegui la soluzione:

       ./solution/run.sh

## Criteri di "fatto"

- [ ] Hai raccolto Dirty prima della write, subito dopo e dopo la sincronizzazione del file.
- [ ] Hai misurato entrambe le scritture e sai distinguere completamento di write da persistenza richiesta con fsync.
- [ ] Il produttore esegue scrittura completa, fsync del file, rename e fsync della directory, in quest'ordine.
- [ ] Il lettore concorrente non osserva stati mancanti, parziali o misti.
- [ ] La copia con conv=fsync supera cmp e produce checksum uguali; non è stato simulato un crash reale.
- [ ] Hai letto la pila dei dispositivi con findmnt e lsblk senza scrivere su un dispositivo a blocchi.
- [ ] Tutti i file di prova sono stati rimossi a fine esercizio.

