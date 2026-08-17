# Cap. 9 — Radiografia di un processo

> Esercizio del **Capitolo 9 — Anatomia di un processo** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- ispezionare stato, memoria, descrittori aperti e namespace di un processo vivo attraverso /proc;
- riconoscere uno zombie e collegarlo alla mancata wait del processo padre;
- distinguere il sonno interrompibile S dal sonno non interrompibile D;
- verificare sperimentalmente l'effetto di SIGKILL su un processo bloccato su una FIFO;
- (passo opzionale, richiede sudo) produrre un vero stato D con un device-mapper `delay` e vedere perché una FIFO non può farlo.

## Prerequisiti

- Un host Linux con /proc montato.
- Un compilatore C e i comandi bash, ps, awk, sed, readlink e mkfifo.
- Nessun privilegio amministrativo per i primi tre passi. Il laboratorio crea soltanto processi dell'utente corrente e una directory temporanea con prefisso labcap09.
- Per il passo opzionale sul vero stato D: privilegi amministrativi e i comandi dmsetup, losetup, truncate e dd (pacchetti device-mapper e util-linux, quasi sempre già presenti). Senza sudo quel passo viene saltato con un messaggio esplicito, il resto del laboratorio funziona comunque.

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

   Una FIFO non produce quindi lo stato D richiesto dalla formulazione originale del laboratorio e non può dimostrare che SIGKILL resti pendente su un'attesa non interrompibile. Un vero D dipende da un percorso del kernel che usa TASK_UNINTERRUPTIBLE, tipicamente durante particolari attese I/O. Provocarlo richiederebbe un meccanismo diverso e un isolamento aggiuntivo — il passo 6 lo fa davvero, senza sostituire questa misura con un'etichetta falsa.

6. Passo opzionale, richiede sudo: produci un vero stato D con il target device-mapper `delay`. Lo script crea un file di backing di 32 MB, lo collega a un loop device, e vi mappa sopra un device `delay` che ritarda ogni I/O di 5 secondi:

      sudo dmsetup create labcap09-delay --noudevsync --table "0 65536 delay /dev/loopN 0 5000"

   `--noudevsync` evita che il comando resti in attesa (potenzialmente per sempre, su alcune macchine) di una conferma da udev che il kernel non deve a nessuno per aver già creato il device — una trappola reale, non teorica, incontrata costruendo questo laboratorio. Una lettura con `dd ... iflag=direct` sul device risultante mostra `ps` con STAT `D` e `/proc/PID/status` con `State: D (disk sleep)` per tutta la durata del ritardo: `iflag=direct` è necessario perché una lettura bufferizzata può essere già servita dalla cache e tornare istantanea senza mai attraversare il ritardo.

   Una seconda trappola, anch'essa reale: le regole udev di sistema lanciano `blkid` su ogni nuovo device-mapper e vi impostano sopra un watch — contro un device `delay` anche solo la sonda di `blkid` costa il ritardo pieno, e `dmsetup remove` rifiuta un device ancora aperto, risultando in un `Device or resource busy` che nessun riprovare risolve da solo. Lo script installa una regola udev temporanea e volatile (in `/run/udev/rules.d/`, non sopravvive a un riavvio), specifica per il solo nome `labcap09-delay`, che dice a udev di ignorare completamente questo device; la rimuove sempre al termine, insieme al device e al loop device, anche in caso di errore.

7. Esegui la soluzione completa e conserva l'output:

      solution/run.sh

   Il trap finale termina soltanto i PID registrati dal laboratorio, rimuove il device-mapper e il loop device se creati, e cancella la directory temporanea. Per includere anche il passo 6: `sudo solution/run.sh`.

## Criteri di "fatto"

- [ ] Hai trovato in /proc il file mantenuto aperto dal processo di prova.
- [ ] Hai letto VmRSS, smaps_rollup e i collegamenti dei namespace del processo.
- [ ] Hai osservato uno stato Z e la sua scomparsa dopo waitpid.
- [ ] Hai osservato che il blocco sulla FIFO è S, non D.
- [ ] Hai verificato che SIGKILL termina il processo bloccato sulla FIFO con stato di attesa 137.
- [ ] Hai annotato perché la FIFO non può dimostrare lo stato D, senza dichiararla verificata comunque.
- [ ] (se hai eseguito il passo 6) Hai osservato STAT `D` e `State: D (disk sleep)` durante l'attesa sul device dm-delay, e il contatore non nullo di `dmsetup status` mentre l'I/O era in sospeso.
- [ ] Nessun processo, device-mapper, loop device o file temporaneo labcap09 rimane al termine.

## Sicurezza

Invia segnali soltanto ai PID stampati dallo script. Non scegliere processi reali dalla classifica di ps. La soluzione non monta filesystem e non modifica impostazioni del kernel. I primi tre passi non richiedono sudo. Il passo 6 (dm-delay) richiede sudo per creare un device-mapper: lavora esclusivamente su un file di backing creato dallo script, mai su un device o volume reale, e lo rimuove sempre, anche in caso di errore — non tocca in alcun modo i volumi LVM o i dischi esistenti della macchina.
