# Cap. 14 — Il condominio Pod: due coinquilini, un portiere invisibile

> Esercizio del **Capitolo 14 — Il Pod in profondità** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- dimostrare perché l'unità è il Pod e non il container: due container che si parlano via localhost e si passano file su un volume condiviso;
- smascherare il pause container: prima dagli inode dei namespace sul nodo, poi — rendendo il condominio "di vetro" — vedendolo comparire come PID 1 dentro il Pod;
- osservare un init container fare il portiere (la fase Init:0/1 dal vivo) e leggere la classe QoS di tre Pod dalle loro resources — ritrovandola nella gerarchia cgroup del cap. 3.

## Prerequisiti

- Cap. 13 completato (crictl e la discesa al nodo non ti spaventano più).
- Il cluster book-labs acceso; accesso al nodo con docker exec.
- Tre manifest in start/ con i TODO: condo.yaml, init.yaml, qos-trio.yaml. (Nel condominio compare l'immagine busybox:stable: la sua httpd ci fa da web server in due kilobyte — la busybox di alpine ne è sprovvista.)

## Consegna

1. Il condominio. Completa start/condo.yaml: un Pod con due container e un volume emptyDir montato da entrambi su /www — "web" serve la cartella con httpd (httpd -f -p 8080 -h /www), "writer" ci scrive dentro la data ogni due secondi (i TODO guidano il secondo container). Applica e interroga un coinquilino sull'altro:

       kubectl apply -f condo.yaml
       kubectl exec condo -c writer -- wget -qO- http://localhost:8080

   Il writer ha appena letto VIA LOCALHOST una pagina servita dall'altro container, il cui contenuto è il file che lui stesso scrive sul volume: rete condivisa e disco condiviso, in un colpo solo. Riprova dopo qualche secondo: la data cambia.

2. Le prove dal nodo (il metodo del cap. 13). Trova i PID dei due container e confronta i loro namespace:

       NODE=$(kubectl get pod condo -o jsonpath='{.spec.nodeName}')
       W=$(docker exec $NODE crictl ps --name writer -q)
       H=$(docker exec $NODE crictl ps --name web -q)
       PW=$(docker exec $NODE crictl inspect -o go-template --template '{{.info.pid}}' $W)
       PH=$(docker exec $NODE crictl inspect -o go-template --template '{{.info.pid}}' $H)
       docker exec $NODE readlink /proc/$PW/ns/net /proc/$PH/ns/net
       docker exec $NODE readlink /proc/$PW/ns/pid /proc/$PH/ns/pid

   Stesso inode di rete (ecco il localhost condiviso), PID namespace diversi (ognuno il suo albero). E chi tiene in vita quei namespace se i coinquilini muoiono? Cerca il portiere:

       docker exec $NODE ps -ef | grep /pause

3. Il condominio di vetro. Aggiungi al tuo condo.yaml la riga shareProcessNamespace: true (nella spec del Pod), cambia il nome in condo-glass e applica. Poi guarda l'altro coinquilino... da dentro:

       kubectl exec condo-glass -c writer -- ps aux

   Ci sono tutti: il writer, l'httpd dell'altro container e — come PID 1 — /pause. Il portiere invisibile del §14.2, visto senza nemmeno scendere dal nodo. Annota chi è PID 1 qui e chi lo era nel cap. 2.

4. Il portiere del cancello. Completa start/init.yaml: un initContainer "gatekeeper" che aspetta 8 secondi e scrive /shared/gate su un emptyDir, e il container principale che parte solo dopo (legge il file e dorme). Applica col watch acceso:

       kubectl apply -f init.yaml
       kubectl get pod init-demo -w

   Guarda la sequenza degli stati: Init:0/1 → PodInitializing → Running. L'init container è sequenziale e muore compiuto; i sidecar del §14.3 (restartPolicy Always sull'init) sono la sua evoluzione che resta viva.

5. Le tre caste (14.5). Completa start/qos-trio.yaml: tre Pod dormienti — nessuna resources (povero), requests più basse dei limits (medio), requests uguali ai limits (garantito). Applica e chiedi al cluster il verdetto:

       kubectl apply -f qos-trio.yaml
       kubectl get pod poor middle royal -o custom-columns='POD:.metadata.name,QOS:.status.qosClass'

   BestEffort, Burstable, Guaranteed: non le hai dichiarate tu — le ha dedotte l'apiserver dalle resources. Nel cap. 13 hai visto il percorso cgroup con kubepods-besteffort: è qui che le caste diventano cartelle (e priorità di eviction, cap. 12).

6. Le domande per answers.md: (a) perché il Pod e non il container: usa le tue prove (localhost, volume, inode net identici, il pause come PID 1) e spiega che mestiere fa il pause container; (b) init container contro sidecar: cosa garantisce la sequenza Init e quando invece serve un compagno che resti vivo; (c) le tre caste: dove finisce ciascuna nella gerarchia cgroup, e in che ordine muoiono quando il nodo è sotto pressione (cap. 12)? Perché "Guaranteed" non significa "più veloce" ma "più protetto"?

7. Smonta il laboratorio:

       kubectl delete pod condo condo-glass init-demo poor middle royal

## Criteri di "fatto"

- [ ] Il wget dal writer restituisce la data scritta dall'altro container (localhost + volume condivisi).
- [ ] Hai gli inode: net identico tra i due container, pid diversi, e hai trovato il processo /pause sul nodo.
- [ ] In condo-glass hai visto /pause come PID 1 da dentro il Pod.
- [ ] Hai osservato la fase Init:0/1 e i tre verdetti QoS (BestEffort, Burstable, Guaranteed).
- [ ] answers.md risponde alle tre domande e i sei Pod sono stati rimossi.
