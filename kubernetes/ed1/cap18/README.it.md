# Cap. 18 — L'indirizzo che non esiste (Service e kube-proxy)

> Esercizio del **Capitolo 18 — I Servizi e la magia di kube-proxy** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Intermedio

## Obiettivi

Al termine di questo laboratorio saprai:

- toccare il problema che i Service risolvono: Pod effimeri, IP che cambiano a ogni rinascita;
- usare un ClusterIP stabile e bilanciato — e poi smascherarlo: non esiste su nessuna interfaccia, è un trucco di iptables (DNAT più una moneta di netfilter, il cap. 6 in grande stile);
- seguire la catena che tiene aggiornata la lista: EndpointSlice che si accorge di ogni nascita e morte, e CoreDNS che dà al tutto l'unico nome davvero stabile.

## Prerequisiti

- Cap. 6, 12, 16 nel bagaglio (iptables, readiness, headless).
- Il cluster book-labs acceso; accesso al nodo con docker exec (kind, o minikube su driver Docker).
- Il manifest start/helpdesk.yaml col TODO sul Service.

## Consegna

1. Il problema. Nel manifest start/helpdesk.yaml il Deployment è già dato: due centralinisti che rispondono col proprio nome (busybox httpd che serve l'hostname). Applica e prova a chiamarli per IP:

       kubectl apply -f helpdesk.yaml
       kubectl get pods -l app=helpdesk -o wide

   Annota gli IP. Ora crea un cliente e chiama il primo centralinista al suo numero diretto:

       kubectl run client --image=busybox:stable -- sleep infinity
       kubectl exec client -- wget -qO- http://<ip-del-primo-pod>:8080

   Risponde. Ma cancella quel pod, aspetta il sostituto e riguarda gli IP: il numero diretto è morto con lui. Chi si salva i numeri diretti dei Pod ha già perso.

2. Il centralino. Completa il TODO del Service nel manifest: selector app=helpdesk, porta 80 verso la 8080. Riapplica e chiama il centralino, più volte:

       kubectl get service helpdesk
       kubectl exec client -- wget -qO- http://helpdesk
       kubectl exec client -- wget -qO- http://helpdesk
       kubectl exec client -- wget -qO- http://helpdesk

   Un IP stabile (il CLUSTER-IP), un nome, e le risposte che si alternano tra i due centralinisti: bilanciamento incluso.

3. L'indagine: quell'IP non esiste. Cerca il ClusterIP sulle interfacce del nodo:

       CIP=$(kubectl get svc helpdesk -o jsonpath='{.spec.clusterIP}')
       NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
       docker exec $NODE ip addr | grep $CIP

   Niente. Nessuna interfaccia, di nessun nodo, ha quell'indirizzo. Eppure wget funziona. Il trucco è nel posto che conosci dal cap. 6:

       docker exec $NODE iptables-save | grep helpdesk

   Eccole: la catena KUBE-SVC del tuo Service, le regole con --probability (la moneta!), e le KUBE-SEP con la DNAT verso gli IP veri dei Pod. Il ClusterIP non è un luogo: è una riscrittura di destinazione, decisa da un lancio di moneta di netfilter, su ogni nodo. (Se il grep non trova nulla, il tuo kube-proxy parla nftables: stesso trucco, altro dialetto — docker exec $NODE nft list ruleset.)

4. Chi aggiorna la rubrica. La lista dei numeri veri vive negli EndpointSlice:

       kubectl get endpointslices -l kubernetes.io/service-name=helpdesk -o wide

   Scala a 3 e riguarda:

       kubectl scale deployment helpdesk --replicas=3
       kubectl get endpointslices -l kubernetes.io/service-name=helpdesk -o wide

   La rubrica insegue i Pod in tempo reale: è il solito watch (cap. 9) — il controller degli EndpointSlice aggiorna la lista, kube-proxy su ogni nodo la traduce in iptables. Ricordi la panchina del cap. 12? Era questa rubrica a svuotarsi.

5. Il nome, l'unica cosa stabile. Chiedi a CoreDNS:

       kubectl exec client -- nslookup helpdesk.default.svc.cluster.local

   Risolve sul ClusterIP — non sugli IP dei Pod (confronta col diario del cap. 16: là, headless, il DNS dava gli IP dei singoli). Gerarchia della stabilità: IP dei Pod (effimeri) < ClusterIP (stabile finché il Service vive) < nome DNS (stabile per contratto).

   Le domande per answers.md: (a) ricostruisci il viaggio di un pacchetto da client al centralinista: chi riscrive cosa, dove avviene la DNAT, e perché il ClusterIP non deve esistere su nessuna interfaccia; (b) la moneta di netfilter: come si legge la regola --probability con 2 e con 3 backend, e cosa succede alla rubrica (e quindi alle iptables) quando un pod muore o fallisce la readiness; (c) la gerarchia della stabilità: Service normale vs headless (cap. 16) — cosa risolve il DNS nei due casi e quando vuoi l'uno o l'altro.

6. Smonta il laboratorio:

       kubectl delete -f helpdesk.yaml
       kubectl delete pod client

## Criteri di "fatto"

- [ ] Hai provato sulla tua pelle la morte del numero diretto (IP del pod cambiato dopo la rinascita).
- [ ] Il centralino risponde con entrambe le voci (bilanciamento visto con wget ripetuti).
- [ ] Hai la prova che il ClusterIP non esiste su nessuna interfaccia, e le regole KUBE-SVC/KUBE-SEP con probability e DNAT.
- [ ] Hai visto gli EndpointSlice inseguire lo scale, e il DNS risolvere il nome sul ClusterIP.
- [ ] answers.md risponde alle tre domande e il laboratorio è smontato.
