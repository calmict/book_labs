# Capitolo 1 — Un container è solo un processo

**Livello:** Fondamentale

Il viaggio parte sotto Kubernetes: osservi un processo reale attraverso le due finestre che fanno sembrare un container una macchina separata.

## Obiettivi

- Osservare lo stesso processo dall'host e dal container (1.2).
- Confrontare PID, hostname ed elenco dei processi (1.2, 1.3).
- Distinguere isolamento dei processi e virtualizzazione hardware (1.3).

## Prerequisiti

- Linux con Docker funzionante e accesso al demone.
- Con Docker Desktop, esegui il laboratorio nell'host Linux del demone: il PID non appartiene alla distro WSL.
- Nessun cluster Kubernetes.

## Lo scenario

In start/ trovi observe.sh, valido ma incompleto. Completa tre lacune per registrare le due viste dello stesso processo.

    cd kubernetes/ed1/cap01/start

### Fase 1 — Il PID dell'host (1.2 — TODO 1)

Ottieni con docker inspect il PID assegnato dal kernel al processo sleep.

### Fase 2 — Lo sguardo esterno (1.2 — TODO 2)

Scrivi in host.txt PID, hostname e numero di processi letti dall'host.

### Fase 3 — Lo sguardo interno (1.3 — TODO 3)

Con docker exec registra gli stessi dati in inside.txt, poi esegui il controllo:

    cd ../solution
    ./run.sh

## Criteri di "fatto"

- Il processo ha un PID ordinario sull'host e PID 1 nel container.
- Hostname ed elenco processi mostrano viste isolate.
- run.sh stampa OK 1..4 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 confronta i due PID dello stesso processo.
- OK 2 verifica l'hostname privato.
- OK 3 verifica la lista ridotta dei processi.
- OK 4 dimostra il contrasto: con la modalità PID dell'host il processo non è PID 1.

## Domande di riflessione

**a.** Perché due PID possono indicare lo stesso processo?

**b.** Che cosa isolano hostname ed elenco processi senza creare un nuovo kernel?

**c.** Che cosa dimostra il contrasto con la modalità PID dell'host?

## Pulizia

run.sh rimuove entrambi i container e la cartella temporanea anche in caso di errore.

## Dove porta

Il capitolo 2 ricostruisce queste viste direttamente con i namespace Linux, senza runtime.
