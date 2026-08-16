# Cap. 5 — Riconoscere e mettere in salvo la propria catena di avvio

> Esercizio del **Capitolo 5 — BIOS e UEFI: due modi di accendere una macchina** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- distinguere un avvio UEFI da un avvio BIOS osservando l'interfaccia del firmware;
- individuare ed esplorare la EFI System Partition senza modificarla;
- leggere BootCurrent, BootOrder e le voci BootNNNN prodotte da efibootmgr -v;
- creare e verificare un backup della catena di avvio senza scrivere nella NVRAM.

## Prerequisiti

- Un host Linux avviato normalmente, con Bash, findmnt, find, tar e sha256sum.
- efibootmgr. Se manca, installalo con il gestore della distribuzione, per esempio:

       sudo dnf install -y efibootmgr

- Privilegi di sola lettura sulla EFI System Partition. Spesso sono necessari sudo
  o una sessione amministrativa anche quando la partizione è già montata.
- Spazio libero sufficiente per una copia dei file di avvio.

## Consegna

1. Determina il metodo con cui è stata avviata la macchina:

       ls /sys/firmware/efi
       if test -d /sys/firmware/efi; then echo UEFI; else echo BIOS; fi

   La directory presente indica che il kernel ha ricevuto l'interfaccia UEFI. Se è
   assente, non inventare voci o partizioni: annota che i passi specifici UEFI non
   sono applicabili a questo avvio.

2. Su una macchina UEFI, individua la EFI System Partition e controlla le opzioni
   di mount:

       findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS /boot/efi

   Esplorala in sola lettura. Se i permessi lo richiedono, anteponi sudo:

       find /boot/efi -maxdepth 4 -printf '%y %P\n' | sort

   Riconosci le directory dei fornitori, i loader con estensione .efi e l'eventuale
   percorso di ripiego EFI/BOOT. Non smontare e non rimontare la partizione.

3. Leggi la NVRAM senza modificarla:

       efibootmgr -v

   BootCurrent è la voce usata per l'avvio corrente. BootOrder elenca l'ordine dei
   tentativi. Ogni BootNNNN collega un identificatore a un dispositivo, alla
   partizione e al percorso del loader; l'asterisco indica una voce attiva.

4. Esegui la soluzione indicando una directory di destinazione:

       solution/run.sh "$HOME/boot-backups"

   Lo script acquisisce la sola lettura di ESP e NVRAM, crea un archivio con la
   copia della ESP, il listato, i dati di mount, l'output di efibootmgr -v e le
   impronte SHA-256, poi verifica l'archivio. Il file di backup è l'unico risultato
   persistente; i dati di lavoro temporanei vengono sempre rimossi.

5. Conserva una seconda copia del backup su un supporto diverso dalla macchina e
   annota in start/answers.md dove si trova. Un backup presente soltanto sul disco
   che deve proteggere non basta.

## Comandi da NON eseguire su una macchina in uso

I comandi seguenti sono soltanto esempi da riconoscere: non eseguirli durante il
laboratorio. Possono cancellare una voce o cambiare l'ordine di avvio reale:

       sudo efibootmgr -b 0001 -B
       sudo efibootmgr -o 0001,0000
       sudo efibootmgr -n 0000

Anche una selezione con -b fa parte delle operazioni di modifica quando è abbinata
a un'azione. In questo laboratorio efibootmgr si usa esclusivamente con -v.

## Criteri di "fatto"

- [ ] Hai stabilito UEFI o BIOS dalla presenza di /sys/firmware/efi.
- [ ] In UEFI hai identificato sorgente, tipo e opzioni di mount della ESP.
- [ ] Hai elencato i loader della ESP senza smontarla, rimontarla o scriverci.
- [ ] Hai interpretato BootCurrent, BootOrder e almeno una voce BootNNNN.
- [ ] Hai creato un archivio verificato con copia della ESP, metadati e impronte.
- [ ] Hai previsto una seconda copia su un supporto differente.
- [ ] Non hai eseguito alcun comando efibootmgr che scriva nella NVRAM.
