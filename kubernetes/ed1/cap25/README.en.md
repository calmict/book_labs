# Chapter 25 — The Meter Reader (Prometheus and Grafana)

> Exercise for **Chapter 25 — Prometheus and Grafana: eyes on the cluster** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Cloud Architect

## Objectives

By the end of this lab you will be able to:

- understand the pull model: Prometheus does not wait to be sent data, it goes and knocks on each target's /metrics door, like a meter reader walking house to house;
- bolt the meters on (node-exporter), write the reader's round (the scrape config) and confirm with the up metric that someone answered at each door;
- query the ledger of readings with PromQL through the Prometheus API, tell a gauge from a counter (and why rate is needed), and see that an alert is just a query crossing a threshold — and where Grafana fits.

## Prerequisites

- Chapter 24 completed (Helm: in the real world the kube-prometheus-stack chart installs Prometheus, the operator and Grafana with one helm install; here we assemble them by hand to see the heart) and familiarity with Deployment/Service/ConfigMap.
- The book-labs cluster running. Everything is local-first and light: three pods (Prometheus, node-exporter, a client), no operator, no persistent storage.
- In start/: metrics-stack.yaml (given), prometheus-config.yaml (with a TODO in the round) and servicemonitor.yaml (to read, the operator's way).

## Instructions

1. The meter on the wall. Apply the stack and look at the meter face before even reading it:

       kubectl create namespace monitoring
       kubectl apply -f metrics-stack.yaml -f prometheus-config.yaml
       kubectl -n monitoring rollout status deploy/node-exporter
       kubectl -n monitoring exec client -- wget -qO- http://node-exporter:9100/metrics | grep -E "^node_load1 |^node_memory_MemAvailable_bytes "

   Real node numbers (load, available memory), exposed as plain text on an HTTP page. Nobody sends them: they just sit there, and whoever wants them must go and get them.

2. The reader walks its round. The scrape config is Prometheus's round: which doors to visit. Open prometheus-config.yaml: right now the reader only visits itself. Complete the round by adding the node door (a node job targeting node-exporter:9100). Re-apply, restart Prometheus so it re-reads the round, and check who answered:

       kubectl apply -f prometheus-config.yaml
       kubectl -n monitoring rollout restart deploy/prometheus
       kubectl -n monitoring rollout status deploy/prometheus
       kubectl -n monitoring exec client -- wget -qO- 'http://prometheus:9090/api/v1/query?query=up'

   The up metric is 1 for the prometheus job and for the node job: someone answered at both doors. If a target were down, up would be 0 — which is already half an alert.

3. Query the ledger (PromQL). Now ask the ledger of readings a few questions:

       kubectl -n monitoring exec client -- wget -qO- 'http://prometheus:9090/api/v1/query?query=count(up==1)'
       kubectl -n monitoring exec client -- wget -qO- 'http://prometheus:9090/api/v1/query?query=node_memory_MemAvailable_bytes'
       kubectl -n monitoring exec client -- wget -qO- 'http://prometheus:9090/api/v1/query?query=sum(rate(prometheus_http_requests_total%5B1m%5D))'

   How many targets are up, how much memory is free on the node (a gauge, an instant snapshot), and the pace of HTTP requests (a rate over a counter, which on its own only ever grows). An alert is nothing but one of these with a threshold: up == 0 for two minutes, and it fires.

4. ServiceMonitor and Grafana (the real world). Read servicemonitor.yaml. At scale, nobody hand-edits the reader's round: with the Prometheus Operator (installed via a chart, as in chapter 24) you declare a ServiceMonitor pointing at a Service by label, and the operator generates for you exactly the scrape config you wrote in this lab. Grafana, for its part, takes these same PromQL queries and gives them a face: charts instead of JSON. In the ready-made stack (kube-prometheus-stack) it comes in the box.

5. Tear the watchtower down:

       kubectl delete namespace monitoring

## The questions for answers.md

- (a) The pull model (25.1–25.2). Why does Prometheus go and get metrics (GET on /metrics) instead of receiving them by push? What does up really measure? What is an exporter like node-exporter, and why expose metrics as plain text over HTTP?
- (b) ServiceMonitor and scrape config (25.3). The scrape config you edited is the reader's round written by hand: what does a ServiceMonitor add, and why does the operator model (targets coming and going) beat a hand-edited file at scale? What did the by-hand round teach you about what a ServiceMonitor ultimately produces?
- (c) PromQL, alerting and Grafana (25.4–25.5). What kind of value is up versus node_memory_MemAvailable_bytes (instant vector, gauge)? What does rate() do and why is a counter never read raw? How does an alert become a simple PromQL threshold? And what is Grafana's job in the stack — where would it come from (recall chapter 24)?

## Definition of "done"

- [ ] Saw the meter face: node-exporter metrics as plain text over HTTP.
- [ ] Completed the round: up is 1 for both prometheus and node.
- [ ] Queried the ledger: count(up==1), a node gauge and a rate over a counter.
- [ ] answers.md answers the three questions.
- [ ] The monitoring namespace has been deleted.
