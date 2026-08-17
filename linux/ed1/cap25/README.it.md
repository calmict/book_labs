# Cap. 25 — Riempire lo sportello

> Esercizio del **Capitolo 25 — Pipe e redirection: comporre strumenti** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- misurare la capacità effettiva di una pipe senza supporre un valore fisso;
- osservare la contropressione fra produttore e consumatore;
- riconoscere una subshell creata da una pipeline Bash;
- collegare lo stato 141 a SIGPIPE in presenza di pipefail.

## Prerequisiti

- Linux con Bash e Python 3.
- Il comando head.
- Nessun privilegio amministrativo richiesto.

Le prove usano soltanto pipe fra processi dell'utente, hanno attese brevi e chiudono tutti i descrittori all'uscita.

## Consegna

1. Copia il modello delle risposte ed esegui il misuratore:

       cp start/answers.md answers.md
       python3 solution/pipe-capacity.py

   Il programma crea una pipe, rende non bloccante il lato di scrittura e inserisce byte finché il kernel risponde EAGAIN. Confronta i byte realmente inseriti con F_GETPIPE_SZ. Non assumere che ogni host restituisca lo stesso numero.

2. Nella seconda fase, il produttore riempie una nuova pipe e tenta di scrivere un altro byte. Il consumatore aspetta per un intervallo cronometrato, verifica che il produttore sia ancora bloccato, poi legge spazio sufficiente. Registra quanto è rimasto fermo il produttore e conferma che è ripartito.

3. Riproduci il problema della variabile modificata in una pipeline:

       count=0
       printf '%s\n' one two three | while IFS= read -r line; do
           count=$((count + 1))
       done
       printf 'count=%s\n' "$count"

   In Bash, il while a destra della pipe gira normalmente in una subshell e la modifica non torna alla shell chiamante. Correggi il flusso con la sostituzione di processo:

       count=0
       while IFS= read -r line; do
           count=$((count + 1))
       done < <(printf '%s\n' one two three)
       printf 'count=%s\n' "$count"

4. Rendi eseguibile start/broken-pipefail.sh e avvialo. Registra il suo stato:

       chmod +x start/broken-pipefail.sh
       start/broken-pipefail.sh
       printf 'status=%s\n' "$?"

   head termina dopo una riga e chiude la lettura. Il produttore ripristina esplicitamente la gestione predefinita di SIGPIPE, prova ancora a scrivere e termina con 128 + 13, cioè 141. Con pipefail quello stato diventa lo stato dell'intera pipeline; con set -e lo script si interrompe.

5. Esegui la soluzione completa, che cattura anche i singoli valori di PIPESTATUS:

       ./solution/run.sh

## Criteri di "fatto"

- [ ] Hai misurato la capacità riempiendo davvero una pipe fino a EAGAIN.
- [ ] Hai osservato il produttore bloccato e la sua ripartenza dopo una lettura del consumatore.
- [ ] Hai ottenuto count=0 con la pipeline e count=3 con la sostituzione di processo.
- [ ] Hai provocato lo stato 141 e identificato il produttore come processo terminato da SIGPIPE.
- [ ] Tutti i processi e i descrittori della prova sono terminati.
