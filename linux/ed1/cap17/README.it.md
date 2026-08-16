# Cap. 17 — Un albero, tanti mondi

> Esercizio del **Capitolo 17 — VFS: il livello che unifica i filesystem** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- osservare come un mount nasconde temporaneamente il contenuto della directory sottostante;
- creare una vista privata dell'albero dei mount senza privilegi amministrativi;
- confrontare la stessa pathname dall'interno e dall'esterno di un namespace;
- attraversare /proc/PID/root per raggiungere, quando consentito, la vista di un processo isolato.

## Prerequisiti

- Un host Linux con Bash e le utilità unshare, mount e umount.
- Namespace utente non privilegiati abilitati.
- /proc montato e accessibile per i propri processi.
- Nessun privilegio sudo richiesto.

## Consegna

Esegui la dimostrazione completa con:

    solution/run.sh

Lo script crea una directory scratch privata e avvia il processo isolato esattamente con:

    unshare --user --map-root-user --mount --propagation private

1. Prima del mount, la directory covered contiene labcap17-original.txt. Nel namespace privato, monta un tmpfs da 4 MiB sopra quella directory:

       mount -t tmpfs -o size=4m,nosuid,nodev labcap17tmpfs DIRECTORY

   Elenca la directory: il file originale non è stato cancellato, ma è nascosto dal nuovo filesystem. Crea labcap17-inside-only.txt nel tmpfs, smonta e verifica che il file originale riappaia mentre quello nel tmpfs scompare.

2. Mentre il tmpfs è montato, osserva la stessa pathname dal processo esterno. La vista esterna deve contenere il file originale e non quello interno: il mount non è propagato fuori dal namespace. Confronta anche /proc/PID/mountinfo del processo isolato e quello del processo esterno cercando labcap17tmpfs.

3. Se i permessi di /proc lo consentono, attraversa la radice del processo isolato:

       ls -la /proc/PID/root/PERCORSO_SCRATCH/covered

   Da questo percorso esterno devi vedere labcap17-inside-only.txt. /proc/PID/root non mostra semplicemente il disco dell'host: risolve il percorso usando la vista dei mount del processo indicato. Se una politica hidepid o ptrace nega l'accesso, registra il salto senza cambiare i permessi globali.

4. Riporta confronti e spiegazioni in start/observations.md. Non eseguire manualmente mount sulla vista reale di /tmp o di una directory personale.

Il gestore di uscita smonta il tmpfs dentro il namespace e rimuove la directory scratch. Se il processo viene interrotto, la distruzione del namespace elimina comunque il mount privato.

## Criteri di "fatto"

- [ ] Hai visto il file originale prima del mount, nascosto durante il mount e di nuovo visibile dopo umount.
- [ ] Hai verificato che il file creato nel tmpfs sia visibile soltanto nella vista isolata.
- [ ] Hai confermato da mountinfo che labcap17tmpfs appartiene solo al namespace privato.
- [ ] Hai raggiunto il file interno tramite /proc/PID/root oppure hai documentato il rifiuto dei permessi.
- [ ] Non hai usato sudo e non hai montato nulla nella vista reale dell'host.
- [ ] Al termine non restano processi, mount o directory scratch del laboratorio.
