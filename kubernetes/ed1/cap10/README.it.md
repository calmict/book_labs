# Capitolo 10 — Scrivi il tuo controller in venti righe

**Livello:** Fondamentale

Dopo LIST e WATCH, costruisci il loop che riceve lo stato, misura lo scarto e agisce.

## Obiettivi

- Riconoscere nelle Lease il battito della leader election (10.4).
- Scrivere un controller observe-diff-act e vederlo riparare e potare Pod (10.1).
- Collegare polling, informer, cache e duello tra copie (10.3-10.4).

## Prerequisiti

- Capitoli 7 e 9 completati e un cluster raggiungibile con kubectl.
- Bash. kind mostra la Lease; altre distribuzioni possono produrre uno SKIP motivato.

## Lo scenario

Completa start/minictl.sh nel namespace cap10-lab. Lo stato desiderato è due Pod app=minictl.

### Fase 1 — Osserva (10.1 — TODO 1)

Conta i Pod non in terminazione: questa è la realtà osservata dal controller.

### Fase 2 — Ripara il difetto (10.1 — TODO 2)

Quando il conteggio è inferiore a due, crea un Pod etichettato nel namespace del laboratorio.

### Fase 3 — Pota l'eccesso (10.1 — TODO 3)

Quando il conteggio supera due, scegli un Pod non morente e cancellalo. Poi esegui:

    bash kubernetes/ed1/cap10/solution/run.sh

## Criteri di "fatto"

- Hai letto il rinnovo della Lease, oppure lo SKIP motivato della distribuzione.
- Il controller ripara una cancellazione e pota un eccesso.
- run.sh stampa OK 1..7, o SKIP 1 motivato, e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 legge due renewTime; OK 2 controlla la convergenza iniziale.
- OK 3 e OK 4 verificano riparazione e potatura.
- OK 5 è il cancello: a controller fermo il Pod non ricompare.
- OK 6 mostra due copie senza elezione sullo stesso stato; OK 7 verifica la pulizia.

## Domande di riflessione

**a.** Dove sono observe, diff e act, e come corrispondono al ReplicaSet controller del capitolo 7?

**b.** Perché il polling non scala, e cosa cambiano informer e cache?

**c.** Perché due copie possono duellare, e come una Lease decide leader e subentro?

## Pulizia

Il controllo termina i controller e cancella cap10-lab. Nel percorso manuale termina gli script
con Ctrl-C e cancella lo stesso namespace.

## Dove porta

Hai costruito il loop. Il capitolo 11 mostra il controller che assegna ogni Pod a un nodo.
