# Cap. 13 — L'indagine: chi ha toccato il mio Pod?

> Esercizio del **Capitolo 13 — La vita di un Pod: da kubectl apply al container attivo** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- ricostruire l'intera staffetta di un kubectl apply dalle prove: quattro firme diverse sugli eventi (deployment-controller, replicaset-controller, default-scheduler, kubelet);
- seguire la catena di proprietà Deployment → ReplicaSet → Pod scritta negli ownerReferences, e scendere sotto l'API fino al processo Linux — ritrovando namespace e cgroup delle Fasi 1-2;
- distinguere le due guarigioni: il kubelet che riavvia un container morto (stesso Pod, RESTARTS che sale) e il controller che rimpiazza un Pod cancellato (nome nuovo).

## Prerequisiti

- Fasi 1 e 2 completate (cap. 1-12): questo capitolo è il loro esame di riepilogo.
- Il cluster book-labs acceso; accesso al nodo con docker exec (kind, o minikube su driver Docker).
- Il manifest di partenza start/relay.yaml ha i TODO da completare (da questo capitolo si sale di livello: più YAML scritto da te).

## Consegna

1. Accendi la scatola nera. In un terminale, registra tutto ciò che accade:

       kubectl get events -w

2. Il fatto. Completa start/relay.yaml (un Deployment, 1 replica, etichetta app=relay, container di nome relay con alpine:3 e sleep infinity: i TODO ti guidano) e dal secondo terminale scatena la staffetta:

       kubectl apply -f relay.yaml

   Nel primo terminale, in un paio di secondi, è già tutto finito. Ferma il watch: ora si indaga a freddo.

3. Le quattro firme. Raccogli le prove con il modulo d'indagine (una vista degli eventi che mostra chi ha firmato cosa):

       kubectl get events --sort-by=.metadata.creationTimestamp -o custom-columns='TIME:.metadata.creationTimestamp,FIRMA:.source.component,REASON:.reason,OGGETTO:.involvedObject.name' | grep relay

   Riconosci i firmatari: ScalingReplicaSet (deployment-controller), SuccessfulCreate (replicaset-controller), Scheduled (default-scheduler), Pulled/Created/Started (kubelet). Quattro mani diverse, nessuna regia centrale. Attenzione: i timestamp hanno la precisione del secondo, quindi gli eventi nati nello stesso istante possono comparire mescolati — l'ordine logico lo ricostruisci tu (chi può aver creato cosa?), ed è parte dell'indagine.

4. La catena di proprietà. Tre oggetti sono nati da un solo apply:

       kubectl get deployment,replicaset,pod -l app=relay
       kubectl get pod -l app=relay -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}{" -> "}{.items[0].metadata.ownerReferences[0].name}{"\n"}'
       kubectl get rs -l app=relay -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}{" -> "}{.items[0].metadata.ownerReferences[0].name}{"\n"}'

   Il Pod appartiene al ReplicaSet, che appartiene al Deployment: la staffetta è anche una catena di deleghe scritta nei metadati.

5. Sotto l'API, fino al processo. Entra nel nodo e ritrova le fondamenta:

       NODE=$(kubectl get pods -l app=relay -o jsonpath='{.items[0].spec.nodeName}')
       CID=$(docker exec $NODE crictl ps --name relay -q)
       PID=$(docker exec $NODE crictl inspect -o go-template --template '{{.info.pid}}' $CID)
       docker exec $NODE cat /proc/$PID/cgroup
       docker exec $NODE readlink /proc/$PID/ns/pid

   Eccolo: un processo Linux, nel suo cgroup kubepods (cap. 3 — e nel percorso leggi anche la QoS class, besteffort) e nei suoi namespace (cap. 2), avviato dalla catena runtime (cap. 5) su ordine del kubelet (cap. 12), su un nodo scelto dallo scheduler (cap. 11), per volontà di due controller (cap. 10), il tutto persistito in etcd (cap. 8) attraverso l'apiserver (cap. 9). Un apply, tredici capitoli.

6. Le due guarigioni (§13.4). Prima uccidi il PROCESSO, senza toccare l'API:

       docker exec $NODE kill -9 $PID
       kubectl get pods -l app=relay

   Stesso Pod, RESTARTS salito a 1: se n'è accorto il kubelet (il PLEG del cap. 12) e ha riavviato il container. Ora invece cancella il POD:

       kubectl delete pod <nome-del-pod>
       kubectl get pods -l app=relay

   Nome nuovo: stavolta ha agito il ReplicaSet controller (cap. 7 e 10). Due medici diversi per due morti diverse — annota come si distinguono dall'esterno.

7. Le domande per answers.md, poi smonta:

       kubectl delete deployment relay

   Le domande: (a) la timeline della staffetta con le quattro firme e la mappa firmatario → capitolo (e l'ordine logico ricostruito, al di là dei timestamp); (b) le due guarigioni del passo 6: chi ha agito in ciascun caso, quale segnale lo tradisce (RESTARTS che sale vs nome che cambia), e perché servono entrambi i livelli di guarigione; (c) gli ownerReferences: a cosa servono, e cosa ti aspetti che succeda cancellando il ReplicaSet invece del Pod? (rifletti sulla cascata, e sul fatto che il Deployment se ne accorgerebbe)

## Criteri di "fatto"

- [ ] Hai la timeline con le quattro firme e l'ordine logico ricostruito.
- [ ] Hai la catena Pod → ReplicaSet → Deployment letta dagli ownerReferences.
- [ ] Hai trovato il PID sul nodo e il suo cgroup kubepods con la QoS class nel percorso.
- [ ] Hai osservato entrambe le guarigioni: RESTARTS a 1 dopo il kill -9, nome nuovo dopo il delete.
- [ ] answers.md risponde alle tre domande e il Deployment è stato rimosso.
