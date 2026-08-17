# Cap. 8 — Scrivere un servizio e misurare un avvio

> Esercizio del **Capitolo 8 — PID 1: da init a systemd** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- scrivere e validare una unità utente con dipendenze esplicite;
- configurare e osservare un riavvio automatico;
- distinguere l'avvio immediato con systemctl --user start dall'abilitazione agli avvii futuri con systemctl --user enable;
- confrontare systemd-analyze blame con systemd-analyze critical-chain senza confondere durata e impatto sul percorso critico.

## Prerequisiti

- Un host Linux avviato con systemd.
- Una sessione utente con il bus di systemd disponibile; verifica con:

      systemctl --user is-system-running

- I comandi bash, systemctl, systemd-analyze, install, awk e sed.
- Nessun privilegio amministrativo. Le unità vengono installate sotto ~/.config/systemd/user e i dati transitori sotto la directory runtime dell'utente.

## Consegna

1. Leggi solution/labcap08-ready.service e solution/labcap08-timestamp.service. La prima unità prepara un marcatore ed è una dipendenza oneshot; la seconda la richiama con Wants e After.

2. Copia entrambe le unità in ~/.config/systemd/user, poi informa il gestore utente:

      mkdir -p ~/.config/systemd/user
      install -m 0644 solution/labcap08-ready.service ~/.config/systemd/user/
      install -m 0644 solution/labcap08-timestamp.service ~/.config/systemd/user/
      systemctl --user daemon-reload

3. Avvia il servizio senza abilitarlo e confronta i due stati:

      systemctl --user start labcap08-timestamp.service
      systemctl --user is-active labcap08-timestamp.service
      systemctl --user is-enabled labcap08-timestamp.service

   Il servizio fallisce intenzionalmente soltanto alla prima esecuzione. Restart=on-failure lo riavvia; due timestamp nel file mostrato da solution/run.sh provano le due esecuzioni.

4. Arresta il servizio, abilitalo e verifica che enable da solo non lo avvii:

      systemctl --user stop labcap08-timestamp.service labcap08-ready.service
      systemctl --user enable labcap08-timestamp.service
      systemctl --user is-enabled labcap08-timestamp.service
      systemctl --user is-active labcap08-timestamp.service

   Enable crea il collegamento per un futuro avvio del gestore utente; start cambia lo stato della sessione corrente. Avvialo esplicitamente per completare la prova.

5. Esegui la soluzione completa. Lo script installa le unità, effettua entrambe le prove, mostra log e contatore dei riavvii e rimuove tutto anche in caso di errore:

      solution/run.sh

6. Analizza l'avvio dell'host in sola lettura:

      systemd-analyze blame --no-pager
      systemd-analyze critical-chain --no-pager

   Annota in start/observations.md la prima unità di blame e il percorso critico. Una unità lenta può avere lavorato in parallelo senza ritardare il traguardo; blame misura il tempo trascorso nello stato di attivazione, mentre critical-chain ricostruisce le dipendenze temporali che conducono al traguardo scelto. Anche critical-chain può omettere attese non espresse da dipendenze e non costituisce da solo una diagnosi causale.

7. Se hai eseguito i comandi manualmente, pulisci le unità utente:

      systemctl --user disable --now labcap08-timestamp.service
      systemctl --user stop labcap08-ready.service
      rm -f ~/.config/systemd/user/labcap08-timestamp.service
      rm -f ~/.config/systemd/user/labcap08-ready.service
      systemctl --user daemon-reload
      systemctl --user reset-failed

## Criteri di "fatto"

- [ ] Il servizio principale parte solo dopo la sua dipendenza oneshot.
- [ ] Il log contiene almeno due timestamp e NRestarts è almeno 1.
- [ ] Dopo start il servizio è attivo ma non abilitato.
- [ ] Dopo enable, prima del nuovo start, il servizio è abilitato ma inattivo.
- [ ] Hai confrontato la prima posizione di blame con la catena critica e spiegato perché non identificano necessariamente la stessa unità.
- [ ] Le unità, il collegamento di abilitazione e i dati runtime del laboratorio non esistono più al termine.

## Sicurezza

Il laboratorio usa esclusivamente systemctl --user. Non copiare queste unità in /etc/systemd/system e non anteporre sudo ai comandi. Lo script interrompe l'esecuzione se trova unità omonime già presenti, per non sovrascrivere lavoro esistente.
