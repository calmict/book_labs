# Chapter 25 — Answers (model solution)

## The meter face

    node_load1 0.65
    node_memory_MemAvailable_bytes 1.2784979968e+10

## The reader's round

    up  prometheus => 1
    up  node       => 1

## The ledger

    count(up==1)                                   => 2
    node_memory_MemAvailable_bytes  node           => 12743221248
    sum(rate(prometheus_http_requests_total[1m]))  => 0.104

## The three questions

**a. The pull model (25.1-25.2): why does Prometheus pull instead of
receive pushes, what does up measure, and what is an exporter?**

Prometheus PULLS: on a fixed interval it makes an HTTP GET to each
target's /metrics endpoint and reads whatever numbers are there. Pull,
rather than having every app push into a central sink, buys three things.
First, Prometheus always knows the full list of things it is supposed to
watch (its scrape config / service discovery), so a target that goes
silent is instantly visible — which is exactly what up measures: it is not
a metric the app exposes, it is Prometheus's own record of whether the
last scrape of that target SUCCEEDED (1) or failed (0). With push you
cannot tell "healthy and quiet" from "dead". Second, the targets stay
dumb: they just expose their current numbers as plain text and do not need
to know where Prometheus is, how to authenticate to it, or how to buffer
when it is down. Third, back-pressure and control live in one place —
Prometheus decides how often to scrape, nobody can flood it. An EXPORTER
is a small adapter that speaks /metrics on behalf of something that does
not: node-exporter reads the Linux kernel's counters (/proc, /sys) and
publishes them as node_* metrics in the plain-text exposition format —
one metric per line, name plus optional labels plus a number — so
Prometheus can scrape a machine the same way it scrapes an app.

**b. ServiceMonitor and scrape config (25.3): what does a ServiceMonitor
add over the hand-edited round, why does the operator model win at scale,
and what does a ServiceMonitor compile down to?**

The scrape config you edited is the round written by hand: a static list
of targets (node-exporter:9100). That is fine for three pods and hopeless
for a real cluster, where pods come and go every deploy and their IPs
change constantly — you cannot hand-edit a file fast enough, and a static
target list goes stale the moment a pod is rescheduled. A ServiceMonitor,
a Custom Resource of the Prometheus Operator, replaces the static list
with a RULE: "scrape every Service carrying these labels, on this named
port, this often". The operator watches the cluster, and whenever a
matching Service (and its live Endpoints) appears or disappears it
regenerates Prometheus's scrape config automatically — dynamic targets,
no human in the loop. What it ultimately compiles down to is exactly the
scrape_config stanza you wrote by hand: that is the whole value of doing
it manually here. Once you have seen that a ServiceMonitor is just a
declarative, label-driven way to produce the same job block, the operator
stops being magic — it is a controller (chapter 10's pattern) that turns a
high-level CR into low-level scrape config, the same way a Deployment
turns into pods.

**c. PromQL, alerting and Grafana (25.4-25.5): gauge vs counter, what
rate() does, how an alert is a PromQL threshold, and Grafana's job (and
where it comes from).**

up and node_memory_MemAvailable_bytes are both instant vectors — a set of
series each with one value at the current instant — but they are different
KINDS of metric. A GAUGE (available memory, load, temperature) goes up and
down and is meaningful read raw: 12 GB free means 12 GB free. A COUNTER
(prometheus_http_requests_total) only ever increases, resetting to zero on
restart; its raw value ("4.7 million requests since boot") is almost
useless. rate() is what makes a counter readable: rate(counter[1m])
computes the per-second increase averaged over the last minute (handling
resets), turning "total requests ever" into "requests per second right
now" — which is what you actually want to graph and alert on. An ALERT is
simply a PromQL expression plus a duration: up == 0 is a query that
returns something only when a target is down; wrap it in a rule that says
"if this has results for 2m, fire", and you have alerting — no separate
language, the same PromQL. GRAFANA is the face: it runs PromQL queries
against Prometheus on a schedule and draws the results as time-series
charts, gauges and tables on dashboards — turning the JSON you read by
hand into something a human can watch at a glance. It is a separate
component from Prometheus (Prometheus stores and answers queries; Grafana
visualises), and in practice you rarely install it alone — it arrives
bundled in the kube-prometheus-stack chart, which is the helm install of
chapter 24 pulling someone else's mould: Prometheus, the operator,
default ServiceMonitors, alerting rules and Grafana dashboards, all in one
package.
