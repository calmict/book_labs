# Cap. 7 — Aprire la cassetta in prestito

> Esercizio del **Capitolo 7 — Il kernel prende il controllo** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- distinguere i moduli di dracut dai moduli del kernel presenti nell'initramfs;
- riconoscere i driver scelti per raggiungere il disco e il filesystem della radice;
- individuare gli hook o le unità che preparano /sysroot e il passaggio alla radice vera;
- dimostrare in una VM perché un driver di storage mancante impedisce l'avvio;
- ricostruire un initramfs funzionante senza conoscere la password del guest.

## Prerequisiti

### Parte 1 — Host, sola lettura

- Un host Linux che usa dracut e rende leggibile all'utente corrente
  /boot/initramfs-$(uname -r).img.
- Il comando lsinitrd. Su Rocky Linux, RHEL e Fedora è fornito dal pacchetto
  dracut, normalmente già installato. Verificalo prima di procedere:

       command -v lsinitrd
       command -v dracut

  Se manca, installa il pacchetto dracut con il gestore di pacchetti della tua
  distribuzione. L'installazione è un'attività amministrativa distinta dal
  laboratorio di ispezione.

### Parte 2 — VM dedicata

- Un host Linux x86_64 sul quale l'utente possa leggere e scrivere /dev/kvm.
- qemu-system-x86_64 oppure /usr/libexec/qemu-kvm, qemu-img, timeout, Python 3
  e pexpect.
- Una propria immagine base qcow2 minimale, compatibile con Rocky Linux 9 o
  RHEL 9 e preparata come descritto nell'Appendice A. Non deve essere in uso da
  altre macchine virtuali. Indicane il percorso senza modificare lo script:

       export LABCAP07_BASE_IMAGE=/percorso/immagine-lab.qcow2

- Il menu di GRUB deve comparire sulla console seriale con un timeout di almeno
  10 secondi. Usa la stessa configurazione seriale validata nel Capitolo 6.
- Nell'immagine prevista la radice è /dev/vda3, XFS, e il disco è collegato da
  QEMU come virtio. Lo script verifica questi fatti prima di modificare alcunché.
- Circa 1 GiB di RAM libera e spazio temporaneo sufficiente in /tmp.

La Parte 1 non avvia QEMU e non modifica mai /boot. La Parte 2 modifica soltanto
un overlay temporaneo; l'immagine base è usata come backing file e non è mai
collegata direttamente alla VM.

## Consegna

### Parte 1 — Ispeziona una copia dell'initramfs reale

1. Esegui l'ispezione automatica e conserva l'output:

       set -o pipefail
       solution/inspect-initramfs.sh | tee /tmp/labcap07-inspection.log

   Lo script esegue la stessa operazione di questa sequenza, aggiungendo
   controlli e pulizia della copia temporanea:

       cp "/boot/initramfs-$(uname -r).img" /tmp/labcap07-inspect.img
       lsinitrd /tmp/labcap07-inspect.img
       lsinitrd /tmp/labcap07-inspect.img | grep -i module

2. Nel foglio start/observations.md separa le due famiglie che lsinitrd mostra:
   i moduli di dracut, come rootfs-block e base, sono componenti funzionali del
   generatore; i file con suffisso .ko, eventualmente compresso, sono moduli del
   kernel. Annota i driver relativi a controller, disco e filesystem della tua
   radice.

3. Confronta l'inventario con l'hardware in uso:

       findmnt -no SOURCE,FSTYPE /
       lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINTS
       lspci -k

   Un initramfs host-only contiene soprattutto la catena necessaria a raggiungere
   la radice di quella macchina, insieme alle dipendenze: non è una seconda copia
   di tutti i driver installati sotto /usr/lib/modules.

4. Lo script elenca i nomi reali sotto usr/lib/dracut/hooks e usa lsinitrd -f per
   mostrare gli hook che citano root, mount, devexists, pivot o switch. Nelle
   immagini dracut basate su systemd mostra anche initrd-switch-root.service.
   Individua il controllo che attende il dispositivo della radice e il componente
   che effettua il passaggio da /sysroot alla radice vera. I nomi variano fra
   versioni: non presumere che esista un particolare 90-qualcosa.

### Parte 2 — Rompi e ripara un avvio reale nella VM

5. Leggi gli script prima di eseguirli:

       sed -n '1,280p' solution/vm-lab.sh
       sed -n '1,420p' solution/vm-driver.py

   Verifica 1 vCPU, 768 MiB di RAM, rete user, -no-reboot, console seriale
   multiplexata e timeout di 180 secondi. Deve essere collegato soltanto
   l'overlay creato sotto /tmp.

6. Avvia il laboratorio e conserva il transcript completo:

       set -o pipefail
       solution/vm-lab.sh | tee /tmp/labcap07-session.log

7. Nella fase break lo script apre l'editor della voce GRUB, riconosce il testo
   GRUB version 2.06 e aggiunge init=/bin/bash alla riga linux. La shell è PID 1
   e non richiede credenziali. Prima di scrivere, la soluzione verifica /dev/vda3,
   virtio_blk nell'initramfs sano e il backing file dell'overlay. Monta / e, se
   separato, /boot in scrittura; conserva una copia sana nello stesso overlay;
   legge dracut --help e ricostruisce l'immagine omettendo virtio_blk.

8. Nella fase broken lo stesso overlay riparte con l'initramfs appena alterato.
   Conserva il messaggio letterale di errore mostrato dal tuo dracut e verifica
   che la shell dracut sia raggiunta, che virtio_blk non sia caricato e che
   /dev/vda non esista.

9. Nella fase repair lo script usa ancora lo stesso overlay. Nell'editor GRUB
   sostituisce temporaneamente la riga initrd con la copia sana, aggiunge
   init=/bin/bash alla riga linux e avvia con Ctrl+X. Dalla radice vera ricostruisce
   il nome standard dell'initramfs senza omissioni e verifica che virtio_blk sia
   tornato nell'archivio.

10. Nella fase verify lo stesso overlay esegue un ultimo avvio dal nome standard.
    L'arrivo al prompt di login e il messaggio del kernel che associa virtio_blk
    a vda provano che la radice vera è di nuovo raggiungibile. Al termine il trap
    arresta ogni QEMU residuo e rimuove overlay e directory temporanea.

## Criteri di "fatto"

- [ ] Hai ispezionato una copia, mai il file originale in /boot.
- [ ] Hai distinto moduli dracut e moduli del kernel.
- [ ] Hai collegato i driver di storage e filesystem alla radice dell'host.
- [ ] Hai letto almeno un hook reale e il meccanismo di switch-root.
- [ ] Hai rotto soltanto l'initramfs nell'overlay e osservato la shell dracut.
- [ ] Hai conservato il messaggio di errore reale del guest.
- [ ] Hai riparato l'immagine senza password e verificato il boot finale.
- [ ] Il processo QEMU e la directory temporanea non esistono più.

## Sicurezza

Non eseguire mai i comandi dracut distruttivi della Parte 2 sull'host. Non indicare
come LABCAP07_BASE_IMAGE un disco collegato a un'altra VM. Interrompi lo script se
la verifica dell'overlay, di /dev/vda3 o dell'initramfs sano non passa. L'accesso
all'editor di GRUB consente di aggirare il login ordinario: proteggi console,
firmware, bootloader e cifratura del disco in base al tuo modello di minaccia.
