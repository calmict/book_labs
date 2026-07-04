#!/usr/bin/env bash
set -euo pipefail

# Chapter 24 solution — the mould and the casts: turn hand-written
# manifests into a Helm chart, then install / upgrade / roll back a
# release. Everything is local-first: the chart lives next to this script.

DIR=$(cd "$(dirname "$0")" && pwd)
CHART="$DIR/greeter"
NS=helmlab

command -v helm >/dev/null || {
  echo "ERROR: helm not found — install it (see the chapter prerequisites)" >&2
  exit 1
}
kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}

cleanup() {
  helm uninstall greeter -n "$NS" >/dev/null 2>&1 || true
  kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

# What the release declares (deterministic, reverts on rollback) and what
# a settled, running pod actually serves (after the rollout completes).
declared() {
  kubectl -n "$NS" get cm greeter-page -o jsonpath='{.data.index\.html}' | tr -d '\n'
}
served() {
  kubectl -n "$NS" rollout status deploy/greeter --timeout=90s >/dev/null
  # rollout status can return while old pods from a scale-down are still
  # phase=Running (Terminating). Wait until only the desired number of
  # pods remain, so the one we pick is the current revision.
  local want have pod
  want=$(kubectl -n "$NS" get deploy greeter -o jsonpath='{.spec.replicas}')
  for _ in $(seq 1 30); do
    have=$(kubectl -n "$NS" get pod -l app=greeter --no-headers 2>/dev/null | grep -c .)
    [ "$have" = "$want" ] && break
    sleep 1
  done
  pod=$(kubectl -n "$NS" get pod -l app=greeter \
    --field-selector=status.phase=Running -o name | head -1)
  kubectl -n "$NS" exec "$pod" -- wget -qO- http://localhost:8080 | tr -d '\n'
}

echo "== 1. The mould renders (no install yet) =="
helm lint "$CHART"
helm template greeter "$CHART" | grep -E 'kind:|replicas:|Greetings' | sed 's/^/  /'
echo

echo "== 2. The first cast (revision 1) =="
helm install greeter "$CHART" -n "$NS" --create-namespace --wait --timeout 120s >/dev/null
helm list -n "$NS"
echo "  replicas: $(kubectl -n "$NS" get deploy greeter -o jsonpath='{.spec.replicas}')"
echo "  declared: $(declared)"
echo "  served:   $(served)"
echo

echo "== 3. Recast with new settings (revision 2) =="
helm upgrade greeter "$CHART" -n "$NS" \
  --set replicaCount=3 --set message="Greetings from revision two" \
  --wait --timeout 120s >/dev/null
echo "  replicas: $(kubectl -n "$NS" get deploy greeter -o jsonpath='{.spec.replicas}')"
echo "  declared: $(declared)"
echo "  served:   $(served)  (pods were rolled — thanks to checksum/config)"
helm history -n "$NS" greeter
echo

echo "== 4. Back to the previous cast (rollback) =="
helm rollback greeter 1 -n "$NS" --wait --timeout 120s >/dev/null
echo "  replicas: $(kubectl -n "$NS" get deploy greeter -o jsonpath='{.spec.replicas}')"
echo "  declared: $(declared)"
echo "  served:   $(served)"
helm history -n "$NS" greeter
echo
echo "  Helm keeps the history where it stores release state — Secrets:"
kubectl -n "$NS" get secret -l owner=helm --no-headers | awk '{print "    " $1}'
echo
echo "=== one mould, three casts, and an undo that is itself a new cast ==="
