# Cap. 9 — Radiografia di un processo

> Esercizio del **Capitolo 9 — Anatomia di un processo** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- ispezionare stato, memoria, descrittori aperti e namespace di un processo vivo attraverso /proc;
- riconoscere uno zombie e collegarlo alla mancata wait del processo padre;
- distinguere il sonno interrompibile S dal sonno non interrompibile D;
- verificare sperimentalmente l'effetto di SIGKILL su un processo bloccato su una FIFO.

## Prerequisiti

- Un host Linux con /proc montato.
- Un compilatore C e i comandi bash, ps, awk, sed, readlink e mkfifo.
- Nessun privilegio amministrativo. Il laboratorio crea soltanto processi dell'utente corrente e una directory temporanea con prefisso labcap09.

## Consegna

1. Leggi solution/process-lab.c e solution/run.sh. Il programma di supporto offre tre modalità: mantiene vivo un processo con memoria e file aperti, crea uno zombie controllato e si blocca aprendo una FIFO senza scrittori.

2. Avvia il processo di ispezione tramite solution/run.sh. Lo script mostra prima la vista sintetica di ps e poi legge direttamente:

      /proc/PID/status
      /proc/PID/fd/
      /proc/PID/smaps_rollup
      /proc/PID/ns/

   Individua il file labcap09-open-file.txt fra i collegamenti dei descrittori, confronta VmRSS con Rss e osserva che ogni voce sotto ns è un collegamento a un oggetto del kernel, identificato da tipo e inode.

3. Osserva il figlio zombie prima che il padre esegua waitpid:

      ps -o pid,ppid,stat,wchan,comm -p PID_DEL_FIGLIO
      sed -n '/^State:/p' /proc/PID_DEL_FIGLIO/status

   Lo stato Z e la relazione PPID mostrano che il processo è terminato ma conserva ancora le informazioni necessarie al padre per raccoglierne lo stato di uscita. Lo script invia SIGUSR1 al padre, che esegue waitpid, e verifica che la voce del figlio scompaia da /proc.

4. Esamina la prova della FIFO. Prima del segnale, lo script mostra ps, State da /proc e wchan per il solo processo labcap09. Poi invia SIGKILL, raccoglie il processo e verifica che il PID non esista più.

5. Registra il risultato effettivo in start/observations.md. Su Linux l'apertura o lettura di una FIFO priva della controparte attende in sonno interrompibile: ps mostra S e il canale d'attesa è normalmente wait_for_partner o pipe_read. SIGKILL interrompe l'attesa e termina il processo.

   Una FIFO non produce quindi lo stato D richiesto dalla formulazione originale del laboratorio e non può dimostrare che SIGKILL resti pendente su un'attesa non interrompibile. Un vero D dipende da un percorso del kernel che usa TASK_UNINTERRUPTIBLE, tipicamente durante particolari attese I/O. Provocarlo richiederebbe un meccanismo diverso e un isolamento aggiuntivo; non sostituire la misura con un'etichetta falsa.

6. Esegui la soluzione completa e conserva l'output:

      solution/run.sh

   Il trap finale termina soltanto i PID registrati dal laboratorio e rimuove la directory temporanea.

## Criteri di "fatto"

- [ ] Hai trovato in /proc il file mantenuto aperto dal processo di prova.
- [ ] Hai letto VmRSS, smaps_rollup e i collegamenti dei namespace del processo.
- [ ] Hai osservato uno stato Z e la sua scomparsa dopo waitpid.
- [ ] Hai osservato che il blocco sulla FIFO è S, non D.
- [ ] Hai verificato che SIGKILL termina il processo bloccato sulla FIFO con stato di attesa 137.
- [ ] Hai annotato che la dimostrazione di D non è realizzabile con il meccanismo indicato, senza dichiararla verificata.
- [ ] Nessun processo o file temporaneo labcap09 rimane al termine.

## Sicurezza

Invia segnali soltanto ai PID stampati dallo script. Non scegliere processi reali dalla classifica di ps. La soluzione non monta filesystem, non modifica impostazioni del kernel e non richiede sudo.
