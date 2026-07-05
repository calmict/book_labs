# Chapter 25 — Answers

## The meter face

    # paste here a couple of node-exporter /metrics lines (node_load1, MemAvailable)

## The reader's round

    # paste here the up query result: 1 for job prometheus AND job node

## The ledger

    # paste here: count(up==1), a node gauge value, and a rate over a counter

## The three questions

**a. The pull model (25.1-25.2): why does Prometheus pull instead of
receive pushes, what does up measure, and what is an exporter?**

_(your answer)_

**b. ServiceMonitor and scrape config (25.3): what does a ServiceMonitor
add over the hand-edited round, why does the operator model win at scale,
and what does a ServiceMonitor compile down to?**

_(your answer)_

**c. PromQL, alerting and Grafana (25.4-25.5): gauge vs counter, what
rate() does, how an alert is a PromQL threshold, and Grafana's job (and
where it comes from).**

_(your answer)_
