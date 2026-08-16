# Cap. 16 — Lavorare con i numeri, non con i nomi

> Esercizio del **Capitolo 16 — Tutto è un file: descriptor e I/O** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- osservare la tabella dei descriptor di un processo durante open e close;
- verificare che una redirezione cambia l'oggetto associato a un numero di descriptor;
- riconoscere un file cancellato ma ancora aperto;
- collegare la chiusura dell'ultimo descriptor al recupero dello spazio occupato.

## Prerequisiti

- Un host Linux con Bash 4 o successivo e Python 3.
- lsof installato.
- Accesso in lettura a /proc per i propri processi.
- Circa 20 MiB liberi in /tmp.

## Consegna

Puoi eseguire tutta la dimostrazione automatica con:

    solution/run.sh

1. Il programma fd-lifecycle.py si ferma in tre stati: prima di open, dopo open e dopo close. A ogni stato, elenca /proc/PID/fd e annota quale nuovo numero compare e a quale file punta. Dopo close, verifica che lo stesso numero non esista più.

2. In una subshell, salva stdout nel descriptor 3 e sostituisce il descriptor 1 con un file:

       exec 3>&1
       exec 1>output.txt

   Osserva il collegamento /proc/PID/fd/1. Il comando non cambia nome a stdout: assegna al numero 1 una nuova open file description. L'output di servizio può ancora essere mostrato attraverso il numero 3.

3. Un secondo processo tiene aperto un file da 16 MiB. Cancella il nome dalla directory mentre il descriptor è ancora aperto e cerca il processo con:

       lsof +L1 -p PID

   Registra NAME, SIZE/OFF e NLINK. NAME termina con deleted e NLINK vale zero: il nome non è più raggiungibile, ma il contenuto occupa spazio finché il processo mantiene il riferimento.

4. Permetti al processo di chiudere il descriptor e ripeti lsof. La riga scompare e lo spazio può essere recuperato. Riporta osservazioni e spiegazioni in start/observations.md.

Tutti i file sono creati in una directory temporanea privata. Lo script ha un gestore di uscita che termina gli helper e cancella la directory anche in caso di errore.

## Criteri di "fatto"

- [ ] Hai confrontato la tabella dei descriptor prima di open, dopo open e dopo close.
- [ ] Hai identificato il numero del descriptor aggiunto e poi rimosso.
- [ ] Hai verificato che il descriptor 1 punti al file dopo la redirezione.
- [ ] Hai trovato con lsof il file cancellato ancora aperto, con NLINK uguale a zero.
- [ ] Hai verificato che la voce scompaia dopo close.
- [ ] Nessun processo o file temporaneo del laboratorio resta al termine.
