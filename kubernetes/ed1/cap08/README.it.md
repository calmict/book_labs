# Capitolo 8 — Uccidi il leader: quorum ed elezioni in etcd

**Livello:** Fondamentale

Il desiderio del capitolo 7 deve sopravvivere ai guasti. Qui lo ritrovi come chiave replicata e
misuri la differenza tra perdere un leader e perdere la maggioranza.

## Obiettivi

- Interrogare tre membri etcd e ritrovare un oggetto come chiave (8.1).
- Forzare un'elezione Raft senza cambiare gli indirizzi dei membri (8.2).
- Perdere e ripristinare il quorum di un cluster a tre membri (8.3-8.4).

## Prerequisiti

- Capitolo 7 completato, kind, Docker e kubectl.
- Circa 4 GB di RAM libera.
- Il controllo crea esclusivamente il cluster dedicato book-labs-ha e lo elimina alla fine. Non
  riusa né modifica kind-book-labs.

## Lo scenario

start/kind-ha.yaml descrive tre control-plane. Completa start/raft-lab.sh e, per la prova manuale,
crea il cluster dedicato:

    kind create cluster --config kubernetes/ed1/cap08/start/kind-ha.yaml

### Fase 1 — La memoria come chiavi (8.1 — TODO 1)

Crea raft-lab e usa etcdctl dentro un Pod etcd per trovare /registry/namespaces/raft-lab.

### Fase 2 — L'elezione (8.2 — TODO 2)

Individua l'unico leader, associa il suo IP al nodo kind e metti in pausa quel nodo. Interroga un
superstite: deve emergere un leader diverso mentre l'API continua a rispondere.

### Fase 3 — Il quorum (8.3 — TODO 3)

Metti in pausa un secondo membro e richiedi una lettura consistente con timeout: un solo membro non
forma una maggioranza. Ripristina entrambi e verifica che raft-lab esista ancora. Esegui:

    bash kubernetes/ed1/cap08/solution/run.sh

## Criteri di "fatto"

- Hai visto tre membri, un leader e la chiave del namespace.
- Dopo la prima pausa l'API risponde con un nuovo leader; dopo la seconda non può leggere.
- run.sh stampa OK 1..6 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 controlla tre nodi e un solo leader; OK 2 cerca la chiave in etcd.
- OK 3 prova l'elezione e la disponibilità con due membri.
- OK 4 è il cancello: con un solo membro la lettura consistente deve fallire.
- OK 5 prova recupero e persistenza; OK 6 controlla ripresa dei nodi e pulizia.

## Domande di riflessione

**a.** Qual è la regola di maggioranza e perché due membri non tollerano più guasti di uno?

**b.** Chi elegge il nuovo leader e perché Kubernetes continua a rispondere?

**c.** Perché i container già avviati possono continuare mentre il control plane è congelato?

## Pulizia

Il controllo riprende sempre i nodi messi in pausa. Se ha creato book-labs-ha, lo elimina; se lo ha
trovato già esistente, lo preserva e rimuove soltanto raft-lab.

## Dove porta

Hai osservato la memoria coerente del cluster. Il capitolo 9 segue le richieste attraverso l'unica
porta autorizzata a leggerla e modificarla: l'API server.
