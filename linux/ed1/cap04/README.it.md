# Cap. 4 — Leggere una macchina che non conosci

> Esercizio del **Capitolo 4 — Anatomia di un sistema installato** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- ricavare identità e famiglia di una distribuzione da /etc/os-release;
- riconoscere il gestore dei pacchetti e interrogare il suo database;
- confrontare il kernel in esecuzione con i pacchetti dichiarati come installati;
- usare findmnt e lsblk per trovare directory sostenute da filesystem separati.

## Prerequisiti

- Un host Linux con Bash, uname, findmnt e lsblk.
- rpm su distribuzioni della famiglia RPM oppure dpkg-query su quelle della
  famiglia Debian.
- Nessun privilegio amministrativo: tutti i comandi sono di sola lettura.

## Consegna

Immagina di avere davanti una macchina senza documentazione. Ricostruiscine
l'identità usando soltanto i dati locali e trascrivi le conclusioni in
start/answers.md.

1. Leggi l'intero file di identità, poi estrai i campi più utili senza dedurre il
   sistema dal solo aspetto del terminale:

       cat /etc/os-release
       . /etc/os-release
       printf 'ID=%s\nID_LIKE=%s\nPRETTY_NAME=%s\n' "$ID" "${ID_LIKE:-}" "$PRETTY_NAME"

   ID identifica la distribuzione; ID_LIKE, quando presente, indica la famiglia
   tecnica da cui eredita convenzioni e strumenti.

2. Cerca il gestore dei pacchetti e verifica la conclusione interrogando davvero
   il database. Usa il ramo adatto alla macchina:

       command -v dnf apt-get zypper pacman apk 2>/dev/null
       rpm -qf /usr/bin/bash
       dpkg-query -S /usr/bin/bash

   Uno dei due ultimi comandi può legittimamente non esistere.

3. Registra il kernel realmente in esecuzione:

       uname -r

   Poi cerca la dichiarazione corrispondente nel database dei pacchetti:

       rpm -q "kernel-core-$(uname -r)"
       dpkg-query -W "linux-image-$(uname -r)"

   Anche qui scegli il comando coerente con la famiglia. Se non trovi una
   corrispondenza, non correggere il dato: un container può vedere il kernel
   dell'host senza possederne il pacchetto, mentre un sistema può avere installati
   kernel che non sta usando in questo momento.

4. Ricostruisci la disposizione dei filesystem:

       findmnt --real -o TARGET,SOURCE,FSTYPE,OPTIONS
       lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINTS

   Confronta la sorgente montata su / con quelle di /home, /var, /boot e delle
   altre directory. Una sorgente a blocchi diversa indica un filesystem separato;
   una porzione tra parentesi quadre indica invece un sottoalbero e non una nuova
   partizione indipendente.

5. Esegui la soluzione automatica, che riunisce e controlla le osservazioni:

       solution/run.sh

## Criteri di "fatto"

- [ ] Hai annotato distribuzione, versione e famiglia usando /etc/os-release.
- [ ] Hai identificato il gestore dei pacchetti e interrogato un pacchetto installato.
- [ ] Hai confrontato uname -r con la dichiarazione del database dei pacchetti.
- [ ] Hai elencato le directory sostenute da partizioni a blocchi diverse da quella di /.
- [ ] Hai distinto un mount separato da un semplice sottoalbero della stessa sorgente.
- [ ] solution/run.sh termina con tutti i controlli superati senza modificare il sistema.
