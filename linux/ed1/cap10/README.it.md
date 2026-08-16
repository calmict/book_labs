# Cap. 10 — Duplicarsi, trasformarsi, sparire

> Esercizio del **Capitolo 10 — fork, exec, wait: come nasce e muore un processo** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- osservare dall'esterno la relazione fra un processo genitore e il figlio creato da fork();
- dimostrare che exec() sostituisce il programma senza cambiare il PID;
- riconoscere uno zombie dallo stato Z e rimuoverlo facendo eseguire wait() al genitore.

## Prerequisiti

- Un host Linux con compilatore C, Bash, ps e accesso a /proc.
- Familiarità di base con PID, PPID e segnali.
- Nessun privilegio amministrativo richiesto.

## Consegna

1. Copia start/process_lab.c in una directory di lavoro. Completa le tre funzioni indicate e compila il programma:

       cc -std=c11 -Wall -Wextra -Wpedantic -O2 process_lab.c -o process_lab

2. Nella modalità fork, crea un figlio e mantieni vivi entrambi per pochi secondi. Avvia il programma in background, poi osservalo dall'esterno:

       ./process_lab fork state &
       ps -o pid,ppid,stat,comm -p "$(cat state/parent.pid),$(cat state/child.pid)"

   Verifica che il PPID del figlio coincida con il PID del genitore. Il genitore deve infine raccogliere il figlio con waitpid().

3. Nella modalità exec, salva il PID e sostituisci il programma con sleep tramite exec. Mentre sleep è attivo, confronta il PID salvato con quello osservato:

       ./process_lab exec state &
       launched_pid=$!
       cat state/exec-before.pid
       ps -o pid,stat,comm -p "$launched_pid"

   I due PID devono coincidere, mentre il nome del programma deve essere cambiato in sleep.

4. Nella modalità zombie, fai terminare subito il figlio senza chiamare ancora waitpid() nel genitore. Osserva lo stato Z:

       ./process_lab zombie state &
       ps -o pid,ppid,stat,comm -p "$(cat state/zombie-child.pid)"

5. Non inviare segnali allo zombie. Invia invece SIGUSR1 al genitore, che dovrà reagire chiamando waitpid():

       kill -USR1 "$(cat state/zombie-parent.pid)"
       ps -p "$(cat state/zombie-child.pid)"

   Il secondo comando non deve più trovare il PID del figlio. Registra osservazioni e risposte in answers.md.

6. Per confrontare il tuo risultato con la soluzione completa, esegui:

       ./solution/run.sh

## Criteri di "fatto"

- [ ] ps mostra contemporaneamente genitore e figlio, con la relazione PID/PPID corretta.
- [ ] Il PID prima e dopo exec è identico e il programma osservato dopo exec è sleep.
- [ ] Il figlio terminato appare con stato Z prima della wait del genitore.
- [ ] Dopo SIGUSR1 al genitore, il PID dello zombie non esiste più.
- [ ] Tutti i processi di prova sono terminati e la directory temporanea è stata rimossa.
