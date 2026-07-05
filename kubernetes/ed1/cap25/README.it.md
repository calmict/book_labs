# Cap. 25 — Il lettore dei contatori (Prometheus e Grafana)

> Esercizio del **Capitolo 25 — Prometheus e Grafana: gli occhi sul cluster** del
> *Manuale di Kubernetes* (collana Calm ICT — [calmict.com](https://calmict.com)).

**Livello:** Cloud Architect

## Obiettivi

Al termine di questo laboratorio saprai:

- capire il modello pull: Prometheus non aspetta che gli mandino i dati, va lui a bussare alla porta /metrics di ogni bersaglio, come un lettore dei contatori che passa di casa in casa;
- montare i contatori (node-exporter), scrivere il giro del lettore (lo scrape config) e verificare con la metrica up che a ogni porta abbia risposto qualcuno;
- interrogare il registro delle letture con PromQL via l'API di Prometheus, capire cosa distingue un gauge da un counter (e perché serve rate), e riconoscere che un alert è solo una query che supera una soglia — e dove entra Grafana.

## Prerequisiti

- Cap. 24 completato (Helm: nel mondo reale il pacchetto kube-prometheus-stack installa Prometheus, l'operator e Grafana con un helm install; qui li montiamo a mano per vederne il cuore) e familiarità con Deployment/Service/ConfigMap.
- Il cluster book-labs acceso. Tutto è local-first e leggero: tre pod (Prometheus, node-exporter, un client), nessun operator, nessuna storage persistente.
- In start/: metrics-stack.yaml (dato), prometheus-config.yaml (con un TODO nel giro) e servicemonitor.yaml (da leggere, il modo dell'operator).

## Consegna

1. Il contatore sul muro. Applica lo stack e guarda la faccia del contatore prima ancora di leggerlo:

       kubectl create namespace monitoring
       kubectl apply -f metrics-stack.yaml -f prometheus-config.yaml
       kubectl -n monitoring rollout status deploy/node-exporter
       kubectl -n monitoring exec client -- wget -qO- http://node-exporter:9100/metrics | grep -E "^node_load1 |^node_memory_MemAvailable_bytes "

   Numeri veri del nodo (carico, memoria disponibile), esposti in chiaro su una pagina HTTP. Nessuno li invia: stanno lì, e chi vuole leggerli deve andarci.

2. Il giro del lettore. Lo scrape config è il giro di Prometheus: a quali porte passare. Apri prometheus-config.yaml: al momento il lettore visita solo sé stesso. Completa il giro aggiungendo la porta del nodo (un job node con bersaglio node-exporter:9100). Riapplica, riavvia Prometheus perché rilegga il giro e verifica chi ha risposto:

       kubectl apply -f prometheus-config.yaml
       kubectl -n monitoring rollout restart deploy/prometheus
       kubectl -n monitoring rollout status deploy/prometheus
       kubectl -n monitoring exec client -- wget -qO- 'http://prometheus:9090/api/v1/query?query=up'

   La metrica up vale 1 per il job prometheus e per il job node: a entrambe le porte ha risposto qualcuno. Se un bersaglio fosse spento, up varrebbe 0 — ed è già mezzo alert.

3. Interrogare il registro (PromQL). Ora fai qualche domanda al registro delle letture:

       kubectl -n monitoring exec client -- wget -qO- 'http://prometheus:9090/api/v1/query?query=count(up==1)'
       kubectl -n monitoring exec client -- wget -qO- 'http://prometheus:9090/api/v1/query?query=node_memory_MemAvailable_bytes'
       kubectl -n monitoring exec client -- wget -qO- 'http://prometheus:9090/api/v1/query?query=sum(rate(prometheus_http_requests_total%5B1m%5D))'

   Quanti bersagli sono su, quanta memoria libera sul nodo (un gauge, una foto istantanea), e il ritmo delle richieste HTTP (rate su un counter, che da solo cresce e basta). Un alert non è altro che una di queste query con una soglia: up == 0 per due minuti, e scatta.

4. ServiceMonitor e Grafana (il mondo reale). Leggi servicemonitor.yaml. A scala, nessuno riscrive a mano il giro del lettore: con il Prometheus Operator (installato via chart, come nel cap. 24) dichiari un ServiceMonitor che punta a un Service tramite label, e l'operator genera per te esattamente lo scrape config che hai scritto in questo lab. Grafana, dal canto suo, prende queste stesse query PromQL e dà loro un volto: grafici invece di JSON. Nello stack pronto (kube-prometheus-stack) arriva già in confezione.

5. Smonta la torre di guardia:

       kubectl delete namespace monitoring

## Le domande per answers.md

- (a) Il modello pull (25.1–25.2). Perché Prometheus va a prendere le metriche (GET su /metrics) invece di riceverle in push? Cosa misura davvero up? Cos'è un exporter come node-exporter e perché esporre le metriche come semplice testo su HTTP?
- (b) ServiceMonitor e scrape config (25.3). Lo scrape config che hai modificato è il giro del lettore scritto a mano: cosa aggiunge un ServiceMonitor, e perché a scala il modello dell'operator (bersagli che vanno e vengono) batte un file modificato a mano? Cosa ti ha insegnato il giro fatto a mano su cosa un ServiceMonitor produce, in fondo?
- (c) PromQL, alerting e Grafana (25.4–25.5). Che tipo di valore è up rispetto a node_memory_MemAvailable_bytes (vettore istantaneo, gauge)? Cosa fa rate() e perché un counter da solo non si guarda mai grezzo? Come diventa un alert una semplice soglia PromQL? E qual è il lavoro di Grafana nello stack — da dove arriverebbe (ricorda il cap. 24)?

## Criteri di "fatto"

- [ ] Vista la faccia del contatore: le metriche di node-exporter in chiaro su HTTP.
- [ ] Completato il giro: up vale 1 sia per prometheus sia per node.
- [ ] Interrogato il registro: count(up==1), un gauge di nodo e un rate su counter.
- [ ] answers.md risponde alle tre domande.
- [ ] Il namespace monitoring è stato cancellato.
