# Cap. 12 — Parlare a un processo che non vuole ascoltare

> Esercizio del **Capitolo 12 — Segnali: la messaggistica del kernel** del
> *Manuale di Linux* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- intercettare SIGTERM ed eseguire una chiusura ordinata fuori dal signal handler;
- dimostrare che SIGKILL non può essere intercettato e impedisce la pulizia applicativa;
- usare SIGHUP per rileggere una configurazione senza cambiare PID;
- diagnosticare e correggere un processo PID 1 che fa attendere docker stop per dieci secondi.

## Prerequisiti

- Un host Linux con compilatore C, Bash e i comandi kill, ps e timeout.
- Docker funzionante e il permesso di avviare container per l'ultima parte.
- L'immagine alpine:3.20 disponibile localmente oppure accesso per scaricarla.
- Nessun privilegio amministrativo richiesto.

## Consegna

1. Copia start/signal_service.c in una directory di lavoro. Completa i gestori: devono limitarsi a impostare flag di tipo sig_atomic_t. Il ciclo principale eseguirà lettura della configurazione, scrittura del log e rimozione del file di lavoro.

2. Compila il servizio e avvialo con una configurazione iniziale:

       cc -std=c11 -Wall -Wextra -Wpedantic -O2 signal_service.c -o signal_service
       printf 'mode=initial\n' > service.conf
       ./signal_service service.conf service.log work.marker ready.marker &
       service_pid=$!

3. Sostituisci la configurazione, invia SIGHUP e verifica che lo stesso PID registri il nuovo valore:

       printf 'mode=reloaded\n' > service.conf
       kill -HUP "$service_pid"
       ps -p "$service_pid" -o pid,stat,comm
       cat service.log

4. Invia SIGTERM e attendi il processo. Il log deve contenere la chiusura ordinata e work.marker deve essere stato rimosso:

       kill -TERM "$service_pid"
       wait "$service_pid"
       test ! -e work.marker

5. Avvia una nuova istanza, invia SIGKILL e attendila. Questa volta work.marker deve restare: il kernel termina il processo senza eseguire codice di pulizia.

       kill -KILL "$service_pid"
       wait "$service_pid"
       test -e work.marker

   Rimuovi manualmente il file rimasto dopo aver registrato l'osservazione.

6. Prima della prova container, esamina l'elenco restituito da docker ps e accertati che i comandi successivi usino esclusivamente i nomi labcap12-slow e labcap12-fixed.

7. Riproduci il PID 1 che ignora SIGTERM. Il processo interno ha durata finita, il container ha limiti espliciti e docker stop ha un timeout esterno:

       docker run -d --rm --name labcap12-slow --cpus=0.25 --memory=64m \
         --pids-limit=32 --network none alpine:3.20 \
         sh -c 'trap "" TERM; sleep 60 & wait'
       time timeout --signal=TERM --kill-after=2s 15s docker stop --time 10 labcap12-slow

   docker stop deve attendere circa dieci secondi prima di ricorrere a SIGKILL.

8. Completa start/container_entrypoint.sh in modo che PID 1 intercetti SIGTERM, termini e raccolga il figlio, poi esca. Avvia la versione corretta montando lo script in sola lettura:

       docker run -d --rm --name labcap12-fixed --cpus=0.25 --memory=64m \
         --pids-limit=32 --network none \
         -v "$PWD/container_entrypoint.sh:/lab/container_entrypoint.sh:ro" \
         alpine:3.20 sh /lab/container_entrypoint.sh
       time timeout --signal=TERM --kill-after=2s 15s docker stop --time 10 labcap12-fixed

   L'arresto deve richiedere molto meno di dieci secondi. La soluzione esegue e controlla tutti i passaggi:

       ./solution/run.sh

## Criteri di "fatto"

- [ ] SIGHUP ricarica il valore modificato e il PID del servizio non cambia.
- [ ] SIGTERM produce una riga di chiusura ordinata e rimuove il file di lavoro.
- [ ] SIGKILL lascia il file di lavoro, dimostrando che la pulizia non è stata eseguita.
- [ ] Il container difettoso impiega circa dieci secondi a fermarsi.
- [ ] Il PID 1 corretto inoltra la terminazione al figlio, lo raccoglie e si ferma rapidamente.
- [ ] Nessun processo di prova e nessun container labcap12 rimane attivo.
