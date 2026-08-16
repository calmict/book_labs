# Cap. 2 — Comporre uno strumento che non esiste

> Esercizio del **Capitolo 2 — La filosofia Unix: strumenti che si combinano** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- trasformare un problema operativo in una sequenza di piccoli filtri;
- collegare awk, sort, uniq e head in una pipeline riproducibile;
- distinguere una pipeline concorrente da una semplice sequenza di comandi;
- controllare il risultato intermedio e quello finale senza affidarti alla sola apparenza.

## Prerequisiti

- Un sistema Linux con Bash, awk, sort, uniq, head e diff.
- Accesso a un terminale dalla radice del repository.
- Nessun privilegio amministrativo richiesto.

## Consegna

Il file start/requests-sample.txt è un piccolo registro di richieste HTTP. Devi costruire lo
strumento che risponde a questa domanda: quali percorsi hanno prodotto più risposte
con codice 5xx?

1. Osserva il formato e individua i campi che contengono percorso e codice HTTP:

       head start/requests-sample.txt

2. Estrai soltanto i percorsi delle richieste fallite. Controlla questo risultato
   intermedio prima di aggiungere altri comandi:

       awk '$9 >= 500 && $9 < 600 {print $7}' start/requests-sample.txt

3. Componi la pipeline completa. Ogni comando svolge un solo compito: awk filtra,
   il primo sort raggruppa le righe uguali, uniq le conta, il secondo sort ordina
   i conteggi e head limita il rapporto:

       awk '$9 >= 500 && $9 < 600 {print $7}' start/requests-sample.txt | sort | uniq -c | sort -nr | head -5

4. Salva l'output in report.txt e annota in start/answers.md che cosa entra ed esce
   da ciascun tratto della pipeline.

5. Verifica che una pipe non aspetti necessariamente la fine del comando a sinistra.
   Il produttore scrive una riga, attende due secondi e poi scrive la seconda:

       start/slow-producer.sh | awk '{ print "consumer:", $0; fflush() }'

   La prima riga del consumatore deve apparire durante l'attesa, prima della seconda
   riga del produttore. sort, al contrario, deve leggere tutto l'ingresso prima di
   poter garantire un ordinamento completo: annota questa differenza.

6. Esegui la soluzione automatica e confronta il suo controllo con il tuo rapporto:

       solution/run.sh

## Criteri di "fatto"

- [ ] report.txt contiene i percorsi 5xx, con conteggi decrescenti.
- [ ] Hai verificato almeno un risultato intermedio prima del rapporto finale.
- [ ] start/answers.md descrive il tipo di dati che attraversa ogni pipe.
- [ ] Hai osservato la prima riga del consumatore prima della fine della pausa di due secondi.
- [ ] Sai spiegare perché sort può ritardare l'output pur facendo parte di una pipeline concorrente.
- [ ] solution/run.sh termina con tutti i controlli superati e non lascia file temporanei.
