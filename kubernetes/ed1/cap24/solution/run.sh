#!/usr/bin/env bash
set -euo pipefail

# Chapter 24 solution test. Renders one local chart, installs and upgrades
# a release, proves that the config checksum rolls Pods, then rolls the
# whole release back. Uses one throwaway namespace and no external chart.

DIR=$(cd "$(dirname "$0")" && pwd)
CHART="$DIR/greeter"
NS=helmlab

command -v helm >/dev/null || {
  echo "ERROR: helm not found — install it (see the chapter prerequisites)" >&2
  exit 1
}
command -v kubectl >/dev/null || { echo "ERROR: kubectl is required" >&2; exit 1; }
kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}
echo "PRECHECK cluster reachable and Helm available"

cleanup() {
  helm uninstall greeter -n "$NS" >/dev/null 2>&1 || true
  kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
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
helm lint "$CHART" >/dev/null
rendered=$(helm template greeter "$CHART")
if ! grep -q 'replicas: 1' <<< "$rendered" || ! grep -q 'Greetings from revision one' <<< "$rendered"; then
  echo "UNEXPECTED: the chart did not render its default values" >&2; exit 1
fi
echo "OK 1 - lint passes and the mould renders revision-one values"
echo

echo "== 2. The first cast (revision 1) =="
helm install greeter "$CHART" -n "$NS" --create-namespace --wait --timeout 120s >/dev/null
if [ "$(kubectl -n "$NS" get deploy greeter -o jsonpath='{.spec.replicas}')" != 1 ] || [ "$(declared)" != "Greetings from revision one" ] || [ "$(served)" != "Greetings from revision one" ]; then
  echo "UNEXPECTED: revision 1 is not serving its declared state" >&2; exit 1
fi
echo "OK 2 - revision 1 runs one replica and serves its declared message"
echo

echo "== 3. Recast with new settings (revision 2) =="
before_uid=$(kubectl -n "$NS" get pod -l app=greeter -o jsonpath='{.items[0].metadata.uid}')
helm upgrade greeter "$CHART" -n "$NS" \
  --set replicaCount=3 --set message="Greetings from revision two" \
  --wait --timeout 120s >/dev/null
if [ "$(kubectl -n "$NS" get deploy greeter -o jsonpath='{.spec.replicas}')" != 3 ] || [ "$(declared)" != "Greetings from revision two" ] || [ "$(served)" != "Greetings from revision two" ]; then
  echo "UNEXPECTED: revision 2 is not serving its declared state" >&2; exit 1
fi
after_uids=$(kubectl -n "$NS" get pod -l app=greeter -o jsonpath='{.items[*].metadata.uid}')
if grep -qw "$before_uid" <<< "$after_uids"; then
  echo "UNEXPECTED: checksum/config did not replace the revision-one Pod" >&2; exit 1
fi
echo "OK 3 - the checksum gate bites: changed config produces new Pods and revision-two content"
echo

echo "== 4. Back to the previous cast (rollback) =="
helm rollback greeter 1 -n "$NS" --wait --timeout 120s >/dev/null
history_count=$(helm history -n "$NS" greeter -o json | grep -o '"revision"' | wc -l)
secret_count=$(kubectl -n "$NS" get secret -l owner=helm --no-headers | grep -c .)
if [ "$(kubectl -n "$NS" get deploy greeter -o jsonpath='{.spec.replicas}')" != 1 ] || [ "$(declared)" != "Greetings from revision one" ] || [ "$(served)" != "Greetings from revision one" ] || [ "$history_count" -ne 3 ] || [ "$secret_count" -ne 3 ]; then
  echo "UNEXPECTED: rollback did not restore revision 1 with three stored revisions" >&2; exit 1
fi
echo "OK 4 - rollback restores revision one and Helm records three revision Secrets"
echo
echo "ALL CHECKS PASSED"
