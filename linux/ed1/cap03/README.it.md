# Cap. 3 — Il confine, visto dallo sportello

> Esercizio del **Capitolo 3 — Kernel e user space: la linea che divide i due mondi** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- osservare le richieste che un programma in user space rivolge al kernel;
- contare e classificare le system call con il riepilogo di strace;
- riconoscere ENOENT come esito della ricerca di un file inesistente;
- separare l'identità amministrativa UID 0 dalla modalità privilegiata della CPU.

## Prerequisiti

- Un host Linux con Bash e accesso a un terminale.
- strace installato, verificabile con command -v strace.
- sudo e dnf per installare strace qualora manchi:

       sudo dnf install -y strace

- sudo per la prova finale con un processo di UID 0. I comandi osservati sono di
  sola lettura e non modificano configurazioni o servizi.

## Consegna

1. Verifica che strace sia disponibile:

       command -v strace

   Se il comando non produce un percorso, installa il pacchetto indicato nei
   prerequisiti. Se il sistema impedisce ptrace, fermati e registra il messaggio:
   avere l'eseguibile installato non basta per poter osservare un processo.

2. Conta le richieste al kernel effettuate da un comando molto semplice:

       strace -c /usr/bin/printf 'hello\n'

   Il programma scrive una sola riga, ma caricamento dinamico, memoria, file e
   uscita richiedono molte system call. Copia il riepilogo in start/answers.md e
   annota il totale e la chiamata più frequente.

3. Chiedi a cat di aprire un nome sicuramente inesistente e limita la traccia alle
   operazioni sui file:

       strace -e trace=openat,newfstatat,statx,access cat /tmp/labcap03-file-that-does-not-exist

   cat termina con errore: nella traccia trova la riga relativa a quel percorso,
   il nome della system call e il risultato ENOENT.

4. Ripeti l'osservazione con un processo di UID 0, salvando la traccia:

       sudo strace -qq -e trace=openat,write -o /tmp/labcap03-root.trace sh -c 'printf "uid=%s\n" "$(id -u)"; cat /etc/os-release >/dev/null'

       grep -E 'openat|write' /tmp/labcap03-root.trace | head

   Il valore stampato è 0, ma il processo continua a usare openat e write per
   chiedere servizi al kernel. root è un'identità con autorizzazioni speciali;
   non significa che il normale codice del processo venga eseguito in modalità
   kernel. Rimuovi la traccia temporanea dopo aver trascritto il risultato.

5. Esegui la soluzione automatica:

       solution/run.sh

   Se sudo richiede una password, esegui il comando da un terminale interattivo.

## Criteri di "fatto"

- [ ] Hai ottenuto e annotato il riepilogo strace -c e il numero totale di system call.
- [ ] Hai individuato una openat fallita con ENOENT per il file inesistente.
- [ ] Hai tracciato un processo che stampa UID 0 e hai osservato le sue system call.
- [ ] Sai spiegare perché UID 0 e modalità kernel non sono la stessa cosa.
- [ ] solution/run.sh supera i controlli oppure segnala esplicitamente un divieto a ptrace.
- [ ] Le tracce temporanee sono state eliminate.
