# Capitolo 12 — Il medico di bordo: probe, riavvii e resurrezione

**Livello:** Fondamentale

Dopo la scelta dello scheduler, osservi il kubelet che mantiene il Pod sano e pronto sul nodo.

## Obiettivi

- Vedere una liveness fallita riavviare il container e produrre back-off (12.2).
- Vedere la readiness togliere e restituire traffico senza riavvio (12.2).
- Creare uno static Pod e provarne la resurrezione tramite kubelet (12.1).

## Prerequisiti

- Capitoli 7-11 completati e il cluster kind raggiungibile con kubectl.
- Docker deve poter eseguire comandi nel nodo kind. Il controllo non arresta né riavvia il nodo.

## Lo scenario

Lavora in cap12-lab. Completa le due probe e isola lo static Pod nello stesso namespace.

### Fase 1 — Il processo che mente (12.2 — TODO 1)

Aggiungi la liveness exec. Il processo resta vivo dopo aver rimosso il file; il kubelet lo
riavvia e il marker persistente rende falliti i tentativi successivi, mostrandone il back-off.

### Fase 2 — Il paziente in panchina (12.2 — TODO 2)

Aggiungi la readiness exec. Togliendo il file, il Pod esce dagli endpoint senza riavviarsi; quando
il file ritorna, rientra nel traffico.

### Fase 3 — Il kubelet autonomo (12.1 — TODO 3)

Assegna cap12-lab allo static Pod e colloca il manifest nella directory osservata dal kubelet.
Cancellare il mirror dall'API non basta: solo la rimozione del file lo ferma. Esegui:

    bash kubernetes/ed1/cap12/solution/run.sh

## Criteri di "fatto"

- Hai distinto riavvio liveness e rimozione dal traffico readiness.
- Hai visto lo static Pod risorgere con un nuovo UID.
- run.sh stampa OK 1..9 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 è il cancello senza liveness; OK 2 verifica riavvii, eventi e intervalli crescenti.
- OK 3-5 verificano endpoint sano, rimozione senza riavvio e guarigione.
- OK 6 crea lo static Pod; OK 7 è il cancello della resurrezione.
- OK 8 verifica che il file sia la fonte di verità; OK 9 la pulizia.

## Domande di riflessione

**a.** Perché una liveness errata è più pericolosa di una readiness errata?

**b.** Chi resuscita lo static Pod e come differisce dal ReplicaSet del capitolo 7?

**c.** Perché l'eviction del kubelet è parente dell'OOM kill del capitolo 3?

## Pulizia

Il controllo rimuove il manifest dal nodo e cancella cap12-lab. Nel percorso manuale rimuovi prima
il file dal nodo, attendi la scomparsa del mirror e poi cancella il namespace.

## Dove porta

Ora il viaggio da una richiesta API a un container sano è completo. Il capitolo 13 lo ricompone
attraverso Pod e loro ciclo di vita.
