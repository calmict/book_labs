# Capitolo 11 — Guida lo scheduler e poi scavalcalo

**Livello:** Fondamentale

Il loop ora ha un compito preciso: scegliere il nodo, senza eseguire il Pod.

## Obiettivi

- Distinguere la decisione dello scheduler dall'esecuzione del kubelet (11.1).
- Vedere filtering e scoring attraverso un Pod Pending e i suoi eventi (11.2).
- Guidare le scelte con nodeSelector, anti-affinity, taint e toleration (11.3-11.4).

## Prerequisiti

- kind, Docker e kubectl. Il controllo crea il cluster dedicato book-labs-sched con tre nodi.
- Non usa né modifica il cluster book-labs-control-plane.

## Lo scenario

Lavora nel namespace cap11-lab del cluster dedicato. Completa i tre manifesti in start/.

### Fase 1 — Scavalca lo scheduler (11.1 — TODO 1)

Assegna nodeName a bypass: non avrà un evento Scheduled, ma il kubelet lo eseguirà.

### Fase 2 — Costruisci il filtro (11.2-11.3 — TODO 2)

Richiedi disk=ssd con nodeSelector. Prima nessun nodo passa; poi una label apre la strada.

### Fase 3 — Separa le repliche (11.3 — TODO 3)

Aggiungi anti-affinity rigida. La terza replica resta Pending finché una toleration non apre il
nodo control-plane taintato. Esegui:

    bash kubernetes/ed1/cap11/solution/run.sh

## Criteri di "fatto"

- Hai confrontato il Pod schedulato col Pod assegnato direttamente.
- Hai osservato i due Pending e i motivi FailedScheduling.
- run.sh stampa OK 1..9 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 controlla la topologia; OK 2 e OK 3 distinguono scelta e bypass.
- OK 4 è il cancello del selector; OK 5 verifica la label che lo riapre.
- OK 6 verifica lo spread; OK 7 è il cancello anti-affinity più taint.
- OK 8 verifica la toleration; OK 9 la pulizia completa.

## Domande di riflessione

**a.** Cosa fa davvero lo scheduler, e chi esegue il Pod bypass?

**b.** Cosa ha tenuto picky Pending, cosa lo ha sbloccato e quando interviene lo scoring?

**c.** In quali direzioni opposte agiscono affinity e taint, e cosa concede la toleration?

## Pulizia

Se il controllo crea book-labs-sched, lo elimina. Se lo trova già presente, elimina cap11-lab e
le label del laboratorio lasciando il cluster in esecuzione.

## Dove porta

Hai separato decisione ed esecuzione. Il capitolo 12 sale sul nodo e osserva il kubelet.
