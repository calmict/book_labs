# Chapter 25 — The Meter Reader

**Level:** Cloud Architect

After packaging the platform with Helm, you give it eyes: a reader visits meters and turns raw measurements into verifiable questions.

## Objectives

- Observe the pull model and metrics exposed by node-exporter (25.1, 25.2).
- Declare a static scrape and its ServiceMonitor equivalent (25.3).
- Query gauges and counters with PromQL and connect them to alerts and Grafana (25.4, 25.5).

## Prerequisites

- kubectl available and the book-labs cluster reachable.
- Chapter 24 completed and familiarity with Deployment, Service, and ConfigMap.

## The scenario

Complete TODOs 1..3 in the reader's round, the operator declaration, and the queries. The solution uses three lightweight Pods, with no operator, persistent storage, or Grafana.

    cd kubernetes/ed1/cap25/solution
    ./run.sh

### Phase 1 — Install the meter (25.1, 25.2)

node-exporter exposes load and memory as HTTP text. Prometheus must go and collect them.

### Phase 2 — Write the round (25.1–25.3)

Add the node job to the scrape config and complete the equivalent ServiceMonitor for dynamic targets.

### Phase 3 — Query the ledger (25.4, 25.5)

Complete the queries that count healthy targets, read a gauge, and calculate the rate of a counter.

## Definition of "done"

- [ ] The three TODOs are complete.
- [ ] node-exporter exposes real metrics and Prometheus sees both targets.
- [ ] All three PromQL queries return results.
- [ ] run.sh prints OK 1..4 and ALL CHECKS PASSED.

## How it is verified

- OK 1 verifies the node's HTTP metrics.
- OK 2 is the biting gate: without the job the node target is absent; adding it changes up from one target to two.
- OK 3 matches ServiceMonitor to Service through its label and named port.
- OK 4 executes count, gauge, and rate through the Prometheus API.

## Reflection questions

**a.** Why does Prometheus use pull, what does up measure, and what role does an exporter play?

**b.** What does ServiceMonitor add to a hand-written scrape config, and why does the operator scale better?

**c.** How do gauges and counters differ, why is rate needed, and how do alerts and Grafana use PromQL?

## Cleanup

run.sh deletes the monitoring namespace, including on failure.

## Where this leads

The cluster is now observable. The next chapter makes Git the source of truth and gives reconciliation to ArgoCD.
