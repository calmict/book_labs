# Cap. 6 — Entrare in un sistema dalla porta di servizio

> Esercizio del **Capitolo 6 — Il bootloader e il passaggio di consegne** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- leggere e conservare la riga di comando del kernel in uso;
- modificare temporaneamente una voce di GRUB senza cambiare la configurazione su disco;
- confrontare un avvio silenzioso con uno che mostra i messaggi del kernel;
- raggiungere la modalità di soccorso e avviare /bin/bash come PID 1;
- spiegare perché l'accesso alla console di avvio equivale spesso al controllo del sistema.

## Prerequisiti

- Un host Linux x86_64 con KVM disponibile in lettura e scrittura per l'utente.
- qemu-system-x86_64 oppure qemu-kvm, qemu-img, timeout, Python 3 e pexpect.
- Una propria immagine base qcow2 compatibile con Rocky Linux o RHEL, non in uso
  da altre macchine virtuali. Indicane il percorso prima di avviare il laboratorio:

       export LABCAP06_BASE_IMAGE=/percorso/immagine-lab.qcow2

  Lo script non collega direttamente l'immagine alla macchina virtuale: ogni
  avvio usa un nuovo overlay temporaneo e la base resta in sola lettura.
- Il menu di GRUB deve essere disponibile sia sulla console seriale sia su quella
  locale, con un timeout di almeno 10 secondi. Alcune immagini cloud Debian e
  Ubuntu sono già predisposte; Rocky Linux, RHEL e Fedora richiedono in genere
  una configurazione esplicita. Queste righe di /etc/default/grub sono un esempio:

       GRUB_TERMINAL="serial console"
       GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"
       GRUB_TIMEOUT=15
       GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8 no_timer_check net.ifnames=0 crashkernel=auto"

  Dopo la modifica, rigenera grub.cfg con il comando previsto dalla distribuzione
  e verifica manualmente che il menu compaia su ttyS0 a 115200 baud.
- Circa 1 GiB di RAM libera e spazio temporaneo in /tmp.
- Nessun'altra macchina virtuale o disco deve essere aperto, modificato o arrestato.

## Consegna

1. Conserva la riga di comando dell'host nel foglio di osservazione:

       cat /proc/cmdline

   Il comando è di sola lettura. Copia il risultato in start/observations.md e
   individua almeno root=, ro oppure rw, quiet e init=, se presenti.

2. Leggi lo script prima di eseguirlo:

       sed -n '1,260p' solution/vm-lab.sh
       sed -n '1,320p' solution/vm-driver.py

   Verifica che il disco collegato sia soltanto un overlay in /tmp, che la rete
   sia di tipo user e che CPU, memoria, console, timeout e -no-reboot rispettino
   i limiti dichiarati.

3. Esegui il laboratorio e conserva il transcript:

       solution/vm-lab.sh | tee /tmp/labcap06-session.log

   La soluzione crea un overlay usa e getta nuovo per ogni avvio. Ogni avvio è
   protetto da un timeout di 180 secondi; un trap termina l'eventuale processo
   qemu residuo e rimuove sempre la directory di lavoro.

4. Nel primo avvio la soluzione apre al volo la voce selezionata in GRUB, elimina
   quiet dalla riga linux e aggiunge un marcatore innocuo. Confronta il transcript
   con un avvio silenzioso: devono comparire la riga di comando del kernel e i
   messaggi di inizializzazione prima del prompt di login.

5. Nel secondo avvio aggiunge systemd.unit=rescue.target. Annota il messaggio che
   identifica la modalità di soccorso. Non è necessario autenticarsi: l'arrivo al
   prompt di manutenzione è la prova richiesta.

6. Nel terzo avvio aggiunge init=/bin/bash. La shell stampa /proc/cmdline e lo
   stato del PID 1; verifica che il comando del processo 1 sia /bin/bash. La
   soluzione chiude poi l'emulatore dalla console multiplexata.

7. Se la disposizione della voce GRUB locale differisce da quella prevista, lo
   script si ferma senza dichiarare il test riuscito. Ripeti manualmente il passo:
   seleziona la voce, premi e, porta il cursore sulla riga che inizia con linux,
   elimina soltanto quiet, aggiungi il parametro richiesto e avvia con Ctrl+X.
   La modifica vale per quell'avvio e non viene salvata su disco.

8. Completa start/observations.md con le prove del transcript e con la verifica
   finale che il processo qemu sia terminato e l'overlay sia stato rimosso.

## Criteri di "fatto"

- [ ] Hai conservato e interpretato la riga di comando corrente dell'host.
- [ ] Hai osservato un avvio senza quiet e i messaggi prima nascosti.
- [ ] Hai raggiunto il prompt della modalità di soccorso.
- [ ] Hai verificato /bin/bash come PID 1 con init=/bin/bash.
- [ ] Hai modificato GRUB soltanto al volo, senza scrivere la configurazione di avvio.
- [ ] Hai spiegato il rischio associato all'accesso fisico alla console.
- [ ] Il processo qemu è terminato e la directory con l'overlay non esiste più.
