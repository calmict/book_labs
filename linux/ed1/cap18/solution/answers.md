# Capitolo 18 — Soluzione

## Hard link e inode

original.txt e hard-link.txt sono due nomi dello stesso inode. Dopo ln il loro numero di inode coincide e il contatore dei link è 2. La rimozione di original.txt elimina una voce di directory, non il contenuto: hard-link.txt rimane leggibile e il contatore torna a 1.

## Link simbolico rotto

Un link simbolico contiene un percorso, non un riferimento diretto all'inode del bersaglio. Dopo la rimozione di target.txt, test -L ha successo perché la voce symbolic-link.txt esiste ed è un link; test -e fallisce perché il percorso memorizzato non porta più a un oggetto esistente.

## Esaurimento degli inode

Il filesystem ext4 dell'immagine ha un numero di inode imposto e molto piccolo. Ogni file richiede un inode anche se è vuoto. Quando Ifree arriva a zero, la creazione fallisce con No space left on device mentre df -h mostra ancora spazio dati disponibile. Il messaggio indica quindi l'esaurimento di una risorsa del filesystem, non necessariamente dei blocchi.

## Rinomina atomica

Il produttore completa il file temporaneo e poi usa rename, tramite mv, all'interno dello stesso filesystem. Il nome finale passa in una sola operazione dalla vecchia alla nuova versione. Un lettore può quindi aprire una delle due versioni complete, senza osservare il nome assente o un contenuto scritto a metà.

