# Capitolo 7 — Il primo contatto: uccidi un Pod e guarda chi lo resuscita

**Livello:** Fondamentale

I container ora entrano nel cluster. In questo laboratorio distingui il cervello dalle braccia e
guardi il modello dichiarativo correggere un sabotaggio reale.

## Obiettivi

- Riconoscere i componenti del control plane e il ruolo dei worker (7.1).
- Dichiarare due repliche e osservare il reconciliation loop (7.2).
- Leggere spec e status nello stesso oggetto API (7.3).

## Prerequisiti

- Parte 1 completata e un cluster locale raggiungibile; vedi [SETUP.md](../../SETUP.md).
- kubectl configurato; kubectl get nodes deve rispondere.

## Lo scenario

Completa start/deployment.yaml, poi applicalo nel namespace isolato del laboratorio.

    kubectl create namespace lab-cap07
    kubectl apply -f kubernetes/ed1/cap07/start/deployment.yaml

### Fase 1 — Il desiderio (7.2 — TODO 1)

Richiedi due repliche: questo numero è il contratto che il controller deve mantenere.

### Fase 2 — Le braccia (7.1 — TODO 2)

Scegli alpine:3 e osserva con kubectl get pods -n lab-cap07 -o wide dove girano i container.
Con kubectl get pods -n kube-system riconosci etcd, API server, scheduler e controller manager.

### Fase 3 — Desiderio e realtà (7.3 — TODO 3)

Mantieni vivo il processo, attendi due Pod pronti e confronta spec.replicas con
status.readyReplicas. Elimina un Pod e verifica che ne appaia uno con nome diverso. Interroga infine
kubectl api-resources e kubectl explain deployment.spec.replicas. Esegui il controllo:

    bash kubernetes/ed1/cap07/solution/run.sh

## Criteri di "fatto"

- Hai identificato i quattro componenti del control plane.
- Spec e status convergono a due repliche e il Pod cancellato viene sostituito.
- run.sh stampa OK 1..5 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 riconosce i quattro componenti nel namespace di sistema.
- OK 2 confronta il desiderio con le repliche pronte.
- OK 3 è il cancello: il nome del Pod cancellato deve sparire e comparire un sostituto.
- OK 4 interroga risorse e documentazione incorporate nell'API.
- OK 5 conferma la rimozione del namespace del laboratorio.

## Domande di riflessione

**a.** Qual è il ruolo dei quattro componenti del control plane, e perché il kubelet non è un Pod?

**b.** Cosa confronta il controller dopo la cancellazione e chi crea materialmente il nuovo Pod?

**c.** Chi scrive spec e chi scrive status? Perché questa separazione rende il modello dichiarativo?

## Pulizia

Il controllo elimina lab-cap07 con tutti i suoi oggetti. Per la prova manuale:

    kubectl delete namespace lab-cap07

## Dove porta

Hai visto il desiderio sopravvivere al sabotaggio. Il capitolo 8 scende nella memoria distribuita
che custodisce quel desiderio.
