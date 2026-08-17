# Cap. 20 — Il numero dietro il nome

> Esercizio del **Capitolo 20 — Utenti, gruppi e identità** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- distinguere il nome di un account dal suo UID numerico;
- prevedere l'effetto di una rinumerazione sulla proprietà mostrata per i file;
- diagnosticare permessi incoerenti su un volume condiviso da ambienti con mappe UID diverse;
- seguire una catena PAM e riconoscere i gruppi auth, account, password e session.

## Prerequisiti

- Un host Linux con Bash e Docker funzionante.
- Un'immagine rockylinux:9 disponibile localmente o scaricabile.
- Accesso in sola lettura a /etc/pam.d sull'host.
- Nessun account dell'host viene creato o modificato: tutti i comandi useradd e usermod devono restare nei container avviati con --rm.

## Consegna

1. Avvia un container effimero e crea labcap20alice con UID 21001. Crea fuori dalla sua home un file con proprietario 21001 e osserva con stat sia il numero sia il nome risolto.

       docker run --rm -it --name labcap20-identity rockylinux:9 bash
       useradd --uid 21001 --no-create-home labcap20alice
       touch /tmp/labcap20-owned
       chown 21001:21001 /tmp/labcap20-owned
       stat -c 'uid=%u owner=%U' /tmp/labcap20-owned

2. Cambia l'UID di labcap20alice in 21002. Verifica che l'inode conservi 21001 e che il vecchio numero non risolva più al nome precedente. Assegna poi 21001 a labcap20replacement: senza modificare il file, stat mostrerà il nuovo nome come proprietario. Spiega perché è cambiata la risoluzione del nome, non il numero registrato nell'inode.

       usermod --uid 21002 labcap20alice
       stat -c 'uid=%u owner=%U' /tmp/labcap20-owned
       useradd --uid 21001 --no-create-home labcap20replacement
       stat -c 'uid=%u owner=%U' /tmp/labcap20-owned

3. Crea una directory labcap20-shared nella cartella dell'esercizio. Montala in un primo container, dove labcap20shared ha UID 23001, e crea come quell'utente un file con modo 0600. Chiudi il container con --rm.

4. Monta la stessa directory in un secondo container effimero, ma assegna a labcap20shared UID 24001. Verifica che il nome uguale non basti: il file conserva UID 23001 e l'utente 24001 non può leggerlo. Correggi una mappa UID soltanto dopo aver identificato quale numero deve essere condiviso.

5. Sull'host, leggi /etc/pam.d/login senza modificarlo. Segui le direttive include e substack verso i file esistenti in /etc/pam.d e classifica le regole nei quattro gruppi funzionali:

       awk '$1 ~ /^-?(auth|account|password|session)$/ {print}' /etc/pam.d/login

   auth stabilisce come autenticare, account se l'account è utilizzabile, password come cambiare le credenziali e session che cosa eseguire all'apertura o chiusura della sessione. L'ordine e il controllo di ogni regola fanno parte della catena.

6. Esci da ogni shell del container e verifica che non rimangano container labcap20. Registra output e spiegazioni in answers.md oppure esegui la soluzione automatica:

       ./solution/run.sh

## Criteri di "fatto"

- [ ] useradd e usermod sono stati eseguiti soltanto in un container effimero.
- [ ] Hai osservato l'UID 21001 invariato nell'inode mentre il nome proprietario scompare e poi cambia.
- [ ] Il volume condiviso riproduce un rifiuto di lettura fra UID 23001 e 24001 nonostante il nome utente uguale.
- [ ] Hai identificato auth, account, password e session nella catena PAM dell'host.
- [ ] La lettura PAM non ha modificato file e tutti i container e dati di prova labcap20 sono stati rimossi.

