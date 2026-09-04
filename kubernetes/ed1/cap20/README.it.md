# Capitolo 20 — Il matrimonio combinato

**Livello:** Cloud Architect

Dopo aver instradato le richieste, assegni storage senza legare l'applicazione a un disco preciso:
il PVC chiede, il PV offre e il binder combina il matrimonio.

## Obiettivi

- Legare un PVC a un PV statico compatibile e osservare il vincolo uno-a-uno (20.1).
- Innescare il provisioning dinamico tramite la StorageClass predefinita (20.2).
- Confrontare nei fatti le reclaim policy Retain e Delete (20.3).
- Riconoscere il provisioner come controller e collegarlo all'interfaccia CSI (20.4).

## Prerequisiti

- Un cluster kind, oppure minikube col driver Docker, e un nodo raggiungibile con docker exec.
- Una StorageClass predefinita funzionante.
- Capitoli 10 e 16 completati per reconciliation loop e storage degli StatefulSet.

## Lo scenario

Completa i TODO 1..3 nei manifest di start/: la richiesta statica, quella dinamica e la policy che
conserva i dati. Il test lavora nel namespace lab-cap20 e usa un hostPath sul nodo soltanto per rendere
visibile la persistenza del PV statico.

    cd kubernetes/ed1/cap20/solution
    ./run.sh

### Fase 1 — Il matrimonio statico (20.1)

bride chiede 30Mi della classe manual e si lega al PV compatibile da 50Mi. spinster presenta la stessa
richiesta dopo che il solo PV è occupato e resta Pending: il binding è esclusivo.

### Fase 2 — Il sensale automatico (20.2, 20.4)

cloud non nomina una classe: quella predefinita osserva il PVC e crea un nuovo PV quando tenant lo usa.

### Fase 3 — Due separazioni diverse (20.3)

Eliminando i claim, Delete rimuove il volume dinamico; Retain lascia manual-pv Released e conserva il
file scritto dal Pod.

## Criteri di "fatto"

- [ ] I tre TODO sono completati e i manifest descrivono entrambe le forme di provisioning.
- [ ] spinster resta Pending mentre bride occupa il PV statico.
- [ ] run.sh stampa OK 1..6 e ALL CHECKS PASSED.

## Come viene verificato

- OK 1 verifica il binding statico compatibile.
- OK 2 è il cancello che morde: il secondo claim resta Pending senza un altro PV.
- OK 3 verifica il PV creato dalla StorageClass predefinita.
- OK 4 confronta le policy Delete e Retain.
- OK 5 verifica la scomparsa del PV dinamico.
- OK 6 verifica lo stato Released e i dati conservati dal PV statico.

## Domande di riflessione

**a.** Su quali criteri il binder abbina PVC e PV, perché il legame è uno-a-uno e cosa attende spinster?

**b.** Quando conviene Retain, qual è il rischio di Delete e come si rende riutilizzabile un PV Released?

**c.** Perché CSI, CRI e CNI sono interfacce? Dove compare il pattern del controller nel provisioner?

## Pulizia

run.sh elimina il namespace lab-cap20, entrambi i PV e la directory hostPath creata nel nodo. Non
modifica la StorageClass né la configurazione del cluster.

## Dove porta

Hai separato richiesta e implementazione nello storage. Il capitolo 21 applica lo stesso principio
all'identità e ai permessi: autenticare qualcuno non significa ancora autorizzarlo.
