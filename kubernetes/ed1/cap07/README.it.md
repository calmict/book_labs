# Cap. 7 — Il primo contatto: uccidi un Pod e guarda chi lo resuscita

> Esercizio del **Capitolo 7 — Visione d'insieme dell'architettura** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Fondamentale

## Obiettivi

Al termine di questo laboratorio saprai:

- avviare un cluster locale e riconoscere a vista i componenti del control plane (il cervello) e cosa gira sui worker (le braccia);
- toccare con mano il modello dichiarativo: tu dichiari lo stato desiderato, il reconciliation loop lo insegue — anche contro i tuoi sabotaggi;
- leggere un oggetto Kubernetes come lo vede l'API: spec (desiderato) contro status (osservato), e scoprire che davvero tutto è una risorsa.

## Prerequisiti

- Aver completato la Fase 1 (cap. 1-6): da qui in poi i container li dai per capiti.
- Un cluster locale: segui [SETUP.md](../../SETUP.md) (kind consigliato; va bene anche minikube o k3d).
- kubectl configurato (kubectl get nodes deve rispondere).

## Consegna

1. Avvia il cluster (una volta sola: servirà anche nei prossimi capitoli) e presentati:

       kind create cluster --name book-labs
       kubectl get nodes -o wide

2. Il giro del palazzo: guarda chi c'è nel namespace di sistema e riconosci il cervello:

       kubectl get pods -n kube-system

   Individua e annota: kube-apiserver (il centralino), etcd (la memoria), kube-scheduler (chi decide dove), kube-controller-manager (chi insegue lo stato desiderato), più kube-proxy e il CNI. Nota curiosa: il kubelet NON è nell'elenco — gira come processo sul nodo, fuori dal cluster che sorveglia (con kind: docker exec book-labs-control-plane pgrep -l kubelet — il cap. 5 ti torna utile).

3. Dichiara uno stato desiderato: due repliche di un processo dormiente (i vecchi amici della Fase 1):

       kubectl create deployment lab-cap07 --replicas=2 --image=alpine:3 -- sleep infinity
       kubectl get pods -o wide

   Aspetta che entrambi i Pod siano Running e annota nomi e nodo.

4. Il sabotaggio: uccidi un Pod e osserva il loop al lavoro. In un terminale lascia girare:

       kubectl get pods -w

   e da un secondo terminale:

       kubectl delete pod <uno-dei-due-pod>

   Guarda la sequenza nel primo terminale: il Pod muore, e ne nasce subito uno nuovo con un nome diverso. Tu hai cambiato lo stato osservato, non quello desiderato: il controller ha visto la differenza e l'ha corretta. Chiudi il watch con Ctrl-C.

5. Guarda il contratto scritto: lo stato desiderato e quello osservato vivono nello stesso oggetto:

       kubectl get deployment lab-cap07 -o yaml

   Trova la sezione spec (replicas: 2 — il tuo desiderio) e la sezione status (readyReplicas — la realtà). Tutta Kubernetes è questo confronto, ripetuto all'infinito.

6. Tutto è una risorsa: fatti dare l'elenco completo e interroga la documentazione incorporata:

       kubectl api-resources | head -15
       kubectl explain deployment.spec.replicas

   Anche i nodi, i namespace, gli eventi: tutto si legge con kubectl get. Prova: kubectl get events --sort-by=.metadata.creationTimestamp | tail -5 — riconosci gli eventi del tuo sabotaggio?

   Le tre domande per answers.md: (a) elenca i componenti del control plane visti al passo 2 e il ruolo di ciascuno in una frase; perché il kubelet non compare tra i Pod? (b) racconta il passo 4 dal punto di vista del controller: cosa ha confrontato, cosa ha deciso, chi ha creato materialmente il nuovo Pod? (c) nel YAML del passo 5, chi scrive la spec e chi scrive lo status? Perché questa separazione è il cuore del modello dichiarativo?

7. Pulizia (il cluster puoi lasciarlo su: i prossimi capitoli lo riusano):

       kubectl delete deployment lab-cap07

   Se invece vuoi spegnere tutto: kind delete cluster --name book-labs.

## Criteri di "fatto"

- [ ] kubectl get nodes risponde e hai identificato i 4 componenti del cervello in kube-system.
- [ ] Hai visto nel watch il Pod cancellato e il sostituto nascere con un altro nome, senza alcun tuo intervento.
- [ ] Sai indicare nel YAML del Deployment dove sta il desiderio (spec) e dove la realtà (status).
- [ ] answers.md risponde alle tre domande.
- [ ] Il Deployment di laboratorio è stato rimosso.
