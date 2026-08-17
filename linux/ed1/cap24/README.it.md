# Cap. 24 — Il comando che non hai scritto

> Esercizio del **Capitolo 24 — La shell: cosa fa prima di eseguire** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- distinguere il testo digitato dagli argomenti ricevuti dal programma;
- riconoscere gli effetti di suddivisione in parole e globbing;
- proteggere nomi di file e variabili con le virgolette;
- rendere uno script indipendente dalla directory corrente e dal PATH interattivo.

## Prerequisiti

- Una shell Bash su Linux.
- I comandi env, cat e date.
- Nessun demone cron: il suo ambiente minimale viene simulato con env -i.

Tutte le prove lavorano nella cartella dell'esercizio e la soluzione rimuove i dati temporanei all'uscita.

## Consegna

1. Copia il modello delle risposte. Rendi eseguibile start/print-args.sh e chiamalo con argomenti semplici, spazi, variabili e caratteri jolly:

       cp start/answers.md answers.md
       chmod +x start/print-args.sh
       start/print-args.sh one "two words" '*.log'

   Il finto comando stampa il numero di argomenti e delimita ciascun valore. Confronta virgolette singole, doppie e assenti. Annota ciò che riceve davvero il programma, non soltanto ciò che compare nella riga digitata.

2. Crea due file .log e ripeti il comando con *.log prima senza virgolette e poi fra virgolette. Spiega in quale caso la shell espande il pattern prima di avviare il programma.

3. Crea un file chiamato quarterly report.txt, assegna il nome a una variabile e riproduci l'errore:

       file_name='quarterly report.txt'
       cat $file_name

   La shell passa due nomi a cat. Correggi il comando e verifica il contenuto:

       cat "$file_name"

4. Esamina start/backup-report.sh. Il comando report-helper funziona nella shell interattiva quando la sua directory è nel PATH:

       PATH="$PWD/start:$PATH" start/backup-report.sh /tmp/labcap24-report.txt

   Senza installare alcun crontab, simula cron con ambiente vuoto e un PATH minimale:

       env -i PATH=/usr/bin:/bin "$PWD/start/backup-report.sh" /tmp/labcap24-report.txt

   Registra l'errore. Correggi una copia dello script calcolando la propria directory e invocando report-helper con un percorso assoluto. Evita di affidarti a PWD o al PATH della sessione.

5. Verifica la correzione nello stesso ambiente minimale oppure esegui la dimostrazione completa:

       ./solution/run.sh

6. Elimina answers.md, i file di prova e /tmp/labcap24-report.txt.

## Criteri di "fatto"

- [ ] Hai mostrato il vettore di argomenti risultante da quoting, variabili e globbing.
- [ ] Hai riprodotto il fallimento del nome con spazio e lo hai corretto con le virgolette.
- [ ] Lo script originale riesce con il PATH interattivo ma fallisce con env -i.
- [ ] Lo script corretto riesce con env -i usando un percorso derivato dalla propria posizione.
- [ ] Hai compilato answers.md e rimosso tutti i file temporanei.
