# Cap. 13 — Due processi, un indirizzo, due memorie

> Esercizio del **Capitolo 13 — Memoria virtuale: indirizzi che mentono** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- dimostrare che due processi possono usare lo stesso indirizzo virtuale per contenuti diversi;
- leggere /proc/PID/maps e interpretare permessi e scopo delle principali regioni;
- misurare RSS e PSS in /proc/PID/smaps_rollup e spiegare come vengono conteggiate le pagine condivise.

## Prerequisiti

- Un host Linux a 64 bit con compilatore C, Bash e accesso a /proc per i propri processi.
- I comandi ps, awk, grep e ldd.
- Nessun privilegio amministrativo richiesto.

## Consegna

1. Copia start/memory_lab.c in una directory di lavoro. Completa il programma in modo che riservi con mmap() una pagina privata e anonima all'indirizzo 0x500000000000. Usa MAP_FIXED_NOREPLACE: un errore deve fermare la prova, non sostituire una mappatura esistente.

2. Avvia contemporaneamente due istanze con etichette diverse:

       cc -std=c11 -Wall -Wextra -Wpedantic -O2 memory_lab.c -o memory_lab
       ./memory_lab alpha state &
       alpha_pid=$!
       ./memory_lab beta state &
       beta_pid=$!
       cat state/alpha.initial state/beta.initial

   Entrambe devono riportare 0x500000000000, ma una pagina contiene alpha e l'altra beta.

3. Invia SIGUSR1 soltanto ad alpha per modificarne la pagina; usa SIGUSR2 per chiedere a entrambe le istanze una nuova fotografia:

       kill -USR1 "$alpha_pid"
       kill -USR2 "$alpha_pid" "$beta_pid"
       cat state/alpha.snapshot state/beta.snapshot

   La pagina di alpha deve contenere alpha-changed, quella di beta ancora beta. L'indirizzo identico non implica memoria condivisa: ogni tabella delle pagine lo traduce indipendentemente.

4. Leggi la mappa di una delle istanze mentre è attiva:

       cat "/proc/$alpha_pid/maps"

   Individua e annota almeno queste regioni:

   - il file eseguibile, con segmenti di sola lettura, eseguibili e scrivibili;
   - heap e stack, normalmente privati e scrivibili;
   - la pagina anonima all'indirizzo scelto, privata e scrivibile;
   - librerie dinamiche e linker, con segmenti a permessi diversi;
   - vvar e vdso, esposte dal kernel.

   Interpreta i caratteri dei permessi: r per lettura, w per scrittura, x per esecuzione, p per mappatura privata e s per mappatura condivisa. Un trattino indica il permesso assente.

5. Per entrambe le istanze leggi Rss e Pss:

       awk '$1 == "Rss:" || $1 == "Pss:" { print }' "/proc/$alpha_pid/smaps_rollup"
       awk '$1 == "Rss:" || $1 == "Pss:" { print }' "/proc/$beta_pid/smaps_rollup"

   RSS attribuisce a ogni processo l'intero costo delle pagine residenti che mappa. PSS divide il costo di ogni pagina condivisa per il numero di processi che la condividono. Confronta anche la somma dei due RSS con la somma dei due PSS.

6. Termina entrambe le istanze con SIGTERM e verifica che non siano rimaste attive. Registra misure e interpretazione in observations.md. La soluzione automatizza la prova:

       ./solution/run.sh

## Criteri di "fatto"

- [ ] Due processi distinti riportano lo stesso indirizzo virtuale e valori iniziali diversi.
- [ ] Modificare la pagina di alpha non cambia il valore osservato da beta.
- [ ] Hai identificato eseguibile, heap, stack, pagina anonima, librerie, vvar e vdso leggendo i loro permessi.
- [ ] Hai misurato RSS e PSS per entrambe le istanze e spiegato perché PSS è inferiore in presenza di pagine condivise.
- [ ] Entrambi i processi di prova sono terminati e i file temporanei sono stati rimossi.
