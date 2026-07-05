#!/usr/bin/env bash
set -euo pipefail

# Chapter 25 solution — the meter reader: Prometheus pulls metrics by
# visiting each target's /metrics door. We stand up node-exporter (the
# meter), Prometheus (the reader), complete its round, and ask the ledger
# a few PromQL questions. Local-first: no operator, no Grafana, three pods.

DIR=$(cd "$(dirname "$0")" && pwd)
NS=monitoring

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}

cleanup() {
  kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT
kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true

echo -n "making sure the monitoring namespace is gone "
waited=0
while kubectl get namespace "$NS" >/dev/null 2>&1; do
  echo -n "."
  sleep 3
  waited=$((waited + 3))
  if [ "$waited" -ge 120 ]; then
    echo " timeout" >&2
    exit 1
  fi
done
echo

# Ask the Prometheus HTTP API a PromQL query, from the client pod, and
# pull the plain values out of the JSON (busybox has no jq).
promq() {
  kubectl -n "$NS" exec client -- \
    wget -qO- "http://prometheus:9090/api/v1/query?query=$1" 2>/dev/null
}
values() {
  # extract each "value":[ts,"V"] and print job=... => V where a job label
  # exists; tolerate an empty result set without failing the script.
  { grep -o '{"metric":{[^}]*},"value":\[[0-9.]*,"[^"]*"\]}' \
    | sed -E 's/.*"job":"([^"]*)".*"value":\[[0-9.]*,"([^"]*)"\].*/  \1 => \2/; t; s/.*"value":\[[0-9.]*,"([^"]*)"\].*/  (scalar) => \1/'; } || true
}

kubectl create namespace "$NS" >/dev/null

# the default serviceaccount is provisioned asynchronously; on a freshly
# started cluster the client Pod cannot be created until it exists.
waited=0
until kubectl -n "$NS" get serviceaccount default >/dev/null 2>&1; do
  sleep 1
  waited=$((waited + 1))
  if [ "$waited" -ge 30 ]; then
    echo "ERROR: the default serviceaccount never appeared" >&2
    exit 1
  fi
done

echo "== 1. The meter on the wall (node-exporter /metrics) =="
kubectl apply -f "$DIR/../start/metrics-stack.yaml" >/dev/null
kubectl apply -f "$DIR/prometheus-config.yaml" >/dev/null
kubectl -n "$NS" wait --for=condition=Ready pod/client --timeout=60s >/dev/null
kubectl -n "$NS" rollout status deploy/node-exporter --timeout=120s >/dev/null
# the Service endpoints can lag a second behind the pod being Ready; retry
# until the meter actually answers before reading it.
metrics=""
for _ in $(seq 1 15); do
  metrics=$(kubectl -n "$NS" exec client -- \
    wget -qO- http://node-exporter:9100/metrics 2>/dev/null || true)
  if echo "$metrics" | grep -q '^node_load1 '; then break; fi
  sleep 2
done
echo "$metrics" | grep -E '^node_load1 |^node_memory_MemAvailable_bytes ' | sed 's/^/  /'
echo "  (real node numbers, exposed as plain text — nobody pushes them)"
echo

echo "== 2. The reader walks its round (scrape config) =="
kubectl -n "$NS" rollout status deploy/prometheus --timeout=120s >/dev/null
echo -n "  waiting until both doors answer "
for _ in $(seq 1 30); do
  up=$(promq up)
  if echo "$up" | grep -q '"job":"prometheus"' && echo "$up" | grep -q '"job":"node"'; then
    break
  fi
  echo -n "."
  sleep 2
done
echo
echo "  up (did someone answer at each door?):"
promq 'up' | values
echo

# a few more scrape cycles so rate() over a window has enough samples
sleep 8
echo "== 3. Asking the ledger (PromQL) =="
echo "  count(up==1) — how many targets are up:"
promq 'count(up==1)' | values
echo "  node_memory_MemAvailable_bytes — a gauge (an instant snapshot):"
promq 'node_memory_MemAvailable_bytes' | values
echo "  sum(rate(prometheus_http_requests_total[1m])) — a counter, seen as a rate:"
rates=$(promq 'sum(rate(prometheus_http_requests_total%5B1m%5D))' | values)
if [ -n "$rates" ]; then head -3 <<< "$rates"; else echo "  (no samples in the window yet)"; fi
echo
echo "  An alert is just one of these with a threshold: up == 0 for a while."
echo
echo "=== the reader walked its round; the ledger answers in PromQL ==="
