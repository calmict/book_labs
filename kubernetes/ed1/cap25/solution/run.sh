#!/usr/bin/env bash
set -euo pipefail

# Chapter 25 solution test. Proves that node-exporter exposes real metrics,
# Prometheus pulls both targets only after the missing scrape job is added,
# and the completed PromQL expressions return the expected value types.
# Uses one throwaway namespace on an existing cluster; no operator or Grafana.

DIR=$(cd "$(dirname "$0")" && pwd)
NS=monitoring

command -v kubectl >/dev/null || { echo "ERROR: kubectl is required" >&2; exit 1; }
kubectl get nodes >/dev/null || { echo "ERROR: no reachable cluster — see chapter 7" >&2; exit 1; }
echo "PRECHECK cluster reachable"

cleanup() {
  kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

promq() {
  kubectl -n "$NS" exec client -- wget -T 3 -qO- \
    "http://prometheus:9090/api/v1/query?query=$1" 2>/dev/null
}
wait_query() {
  local query=$1 pattern=$2 result
  for _ in $(seq 1 40); do
    result=$(promq "$query" || true)
    if grep -q "$pattern" <<< "$result"; then printf '%s' "$result"; return 0; fi
    sleep 2
  done
  return 1
}

kubectl create namespace "$NS" >/dev/null

echo "== 1. The meter exposes node readings =="
kubectl apply -f "$DIR/../start/metrics-stack.yaml" >/dev/null
kubectl apply -f "$DIR/../start/prometheus-config.yaml" >/dev/null
kubectl -n "$NS" wait --for=condition=Ready pod/client --timeout=90s >/dev/null
kubectl -n "$NS" rollout status deploy/node-exporter --timeout=120s >/dev/null
metrics=""
for _ in $(seq 1 30); do
  metrics=$(kubectl -n "$NS" exec client -- wget -qO- http://node-exporter:9100/metrics 2>/dev/null || true)
  if grep -q '^node_load1 ' <<< "$metrics" && grep -q '^node_memory_MemAvailable_bytes ' <<< "$metrics"; then break; fi
  sleep 2
done
if ! grep -q '^node_load1 ' <<< "$metrics" || ! grep -q '^node_memory_MemAvailable_bytes ' <<< "$metrics"; then
  echo "UNEXPECTED: node-exporter did not expose the expected readings" >&2; exit 1
fi
echo "OK 1 - node-exporter exposes load and memory gauges as plain text"

echo "== 2. The scrape-config gate bites =="
kubectl -n "$NS" rollout status deploy/prometheus --timeout=120s >/dev/null
baseline=$(wait_query up '"job":"prometheus"')
if grep -q '"job":"node"' <<< "$baseline"; then
  echo "UNEXPECTED: the incomplete config already scrapes node-exporter" >&2; exit 1
fi
kubectl apply -f "$DIR/prometheus-config.yaml" >/dev/null
# A mounted ConfigMap is refreshed on the kubelet sync cycle. Waiting for
# that cycle avoids restarting Prometheus against the previously cached file.
sleep 65
kubectl -n "$NS" rollout restart deploy/prometheus >/dev/null
kubectl -n "$NS" rollout status deploy/prometheus --timeout=120s >/dev/null
complete=$(wait_query up '"job":"node"')
if ! grep -q '"job":"prometheus"' <<< "$complete" || ! grep -q '"job":"node"' <<< "$complete"; then
  echo "UNEXPECTED: both scrape targets are not present" >&2; exit 1
fi
echo "OK 2 - the gate bites: adding the missing job changes up from one target to two"

echo "== 3. The operator declaration matches the manual round =="
if ! grep -q 'app: node-exporter' "$DIR/servicemonitor.yaml" || ! grep -q 'port: metrics' "$DIR/servicemonitor.yaml"; then
  echo "UNEXPECTED: ServiceMonitor does not select the exporter and named port" >&2; exit 1
fi
echo "OK 3 - ServiceMonitor selects the exporter Service and its metrics port"

echo "== 4. PromQL answers the ledger questions =="
# shellcheck disable=SC1091
source "$DIR/queries.sh"
count_json=$(wait_query "${COUNT_QUERY//[/\%5B}" '"result"')
gauge_json=$(wait_query "$GAUGE_QUERY" 'node_memory_MemAvailable_bytes')
rate_encoded=${RATE_QUERY//[/\%5B}; rate_encoded=${rate_encoded//]/\%5D}
rate_json=$(wait_query "$rate_encoded" '"result"')
if ! grep -Eq '"value":\[[^]]*,"2"\]' <<< "$count_json" || [ -z "$gauge_json" ] || [ -z "$rate_json" ]; then
  echo "UNEXPECTED: one or more PromQL queries returned the wrong result" >&2; exit 1
fi
echo "OK 4 - count, gauge, and rate queries return Prometheus results"
echo "ALL CHECKS PASSED"
