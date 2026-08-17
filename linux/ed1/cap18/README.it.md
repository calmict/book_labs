# Cap. 18 — Il nome non è il file

> Esercizio del **Capitolo 18 — Inode, link e struttura del filesystem** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- distinguere un nome di directory dall'inode a cui punta;
- confrontare hard link e link simbolici quando un nome viene rimosso;
- riconoscere l'esaurimento degli inode anche quando rimane spazio per i dati;
- pubblicare un file completo mediante una rinomina atomica.

## Prerequisiti

- Un host Linux con Bash, coreutils, util-linux ed e2fsprogs.
- Permessi amministrativi per losetup, mount e umount nella sola prova di esaurimento degli inode.
- Almeno 20 MiB liberi nella directory dell'esercizio.
- Nessun dato importante nella directory solution/labcap18-work: lo script la ricrea e la elimina.

## Consegna

1. Crea un file, osservalo con stat e crea un hard link. Confronta numero di inode e contatore dei link prima e dopo la creazione, poi elimina uno dei due nomi e verifica che contenuto e inode rimangano raggiungibili dall'altro.

       printf 'contenuto condiviso\n' > original.txt
       stat -c '%i %h %n' original.txt
       ln original.txt hard-link.txt
       stat -c '%i %h %n' original.txt hard-link.txt
       rm original.txt
       stat -c '%i %h %n' hard-link.txt

2. Crea un link simbolico verso un file, elimina il bersaglio e confronta il risultato di test -L con quello di test -e. Spiega perché il link esiste ancora ma non risolve più un file.

       printf 'bersaglio\n' > target.txt
       ln -s target.txt symbolic-link.txt
       rm target.txt
       test -L symbolic-link.txt
       test -e symbolic-link.txt

3. Crea esclusivamente un'immagine da 16 MiB con pochi inode, associala a un loop device e montala nella directory di laboratorio. Non usare una partizione o un dispositivo reale.

       dd if=/dev/zero of=labcap18.img bs=1M count=16
       mkfs.ext4 -N 128 labcap18.img
       sudo losetup --find --show labcap18.img
       sudo mount DISPOSITIVO_LOOP labcap18-mnt

4. Crea file vuoti nel filesystem montato finché l'operazione fallisce. Confronta df -h e df -i: deve rimanere spazio in byte mentre gli inode disponibili arrivano a zero. Smonta, scollega il loop device e rimuovi immagine e punto di mount anche in caso di errore.

5. Implementa una pubblicazione atomica: scrivi il nuovo contenuto in un file temporaneo nella stessa directory del file finale, chiudilo e sostituisci il nome finale con mv. Avvia contemporaneamente un lettore e verifica che osservi soltanto la versione vecchia o quella nuova, mai un file assente o parziale.

6. Registra osservazioni e output essenziali in answers.md. Puoi eseguire la soluzione completa con privilegi amministrativi:

       sudo ./solution/run.sh

## Criteri di "fatto"

- [ ] I due hard link hanno lo stesso inode e il contatore sale a 2, poi torna a 1 dopo la rimozione di un nome.
- [ ] Il link simbolico rotto è riconosciuto come link ma non come percorso verso un file esistente.
- [ ] L'esaurimento avviene soltanto sull'immagine labcap18.img e df mostra inode esauriti con spazio dati ancora libero.
- [ ] Il lettore della prova di rinomina atomica non osserva stati assenti o parziali.
- [ ] Loop device, mount, immagine e file temporanei sono stati rimossi a fine prova.

