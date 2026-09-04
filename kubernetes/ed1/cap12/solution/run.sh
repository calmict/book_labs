#!/usr/bin/env bash
# Chapter 12 verification - checks liveness restarts, readiness traffic
# removal, and a static Pod recreated by the kubelet. Uses one lab namespace
# and one temporary manifest in the existing kind node, both cleaned on exit.
set -euo pipefail

NS=cap12-lab
DIR=$(cd "$(dirname "$0")" && pwd)
STATIC_PATH=/etc/kubernetes/manifests/cap12-static-hello.yaml

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster - see chapter 7" >&2
  exit 1
}
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec "$NODE" true 2>/dev/null || {
  echo "ERROR: this check needs a kind node reachable with docker exec" >&2
  exit 1
}

cleanup() {
  docker exec "$NODE" rm -f "$STATIC_PATH" 2>/dev/null || true
  kubectl delete namespace "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup
kubectl wait --for=delete namespace/"$NS" --timeout=120s >/dev/null 2>&1 || true
kubectl create namespace "$NS" >/dev/null
echo "PRECHECK using Docker-backed node $NODE and namespace $NS"

kubectl apply -n "$NS" -f "$DIR/../start/pod-liar.yaml" >/dev/null
kubectl wait -n "$NS" --for=condition=Ready pod/liar --timeout=120s >/dev/null
sleep 25
test "$(kubectl get pod liar -n "$NS" -o jsonpath='{.status.containerStatuses[0].restartCount}')" -eq 0
echo "OK 1 - the gate bites: without livenessProbe, the unhealthy process is not restarted"
kubectl delete pod liar -n "$NS" --wait=true >/dev/null

kubectl apply -f "$DIR/pod-liar.yaml" >/dev/null
waited=0
while true; do
  RESTARTS=$(kubectl get pod liar -n "$NS" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || true)
  WAITING=$(kubectl get pod liar -n "$NS" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)
  if [ -n "$RESTARTS" ] && [ "$RESTARTS" -ge 2 ] && [ "$WAITING" = CrashLoopBackOff ]; then break; fi
  sleep 2
  waited=$((waited + 2))
  if [ "$waited" -ge 240 ]; then
    echo "ERROR: timed out waiting for liveness restarts and CrashLoopBackOff" >&2
    exit 1
  fi
done
kubectl get events -n "$NS" --field-selector involvedObject.name=liar -o jsonpath='{range .items[*]}{.reason}{"\n"}{end}' | grep -qx Unhealthy
kubectl get events -n "$NS" --field-selector involvedObject.name=liar -o jsonpath='{range .items[*]}{.reason}{"\n"}{end}' | grep -qx Killing
echo "OK 2 - failed liveness causes repeated restarts and reaches CrashLoopBackOff"

kubectl apply -f "$DIR/pod-moody.yaml" >/dev/null
kubectl wait -n "$NS" --for=condition=Ready pod/moody --timeout=120s >/dev/null
BASE_RESTARTS=$(kubectl get pod moody -n "$NS" -o jsonpath='{.status.containerStatuses[0].restartCount}')
test -n "$(kubectl get endpoints moody -n "$NS" -o jsonpath='{.subsets[0].addresses[0].ip}')"
echo "OK 3 - a ready Pod is present in the Service endpoints"

kubectl exec moody -n "$NS" -- rm /tmp/ready
waited=0
while [ -n "$(kubectl get endpoints moody -n "$NS" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null)" ]; do
  sleep 3
  waited=$((waited + 3))
  if [ "$waited" -ge 90 ]; then
    echo "ERROR: timed out waiting for readiness to remove the endpoint" >&2
    exit 1
  fi
done
test "$(kubectl get pod moody -n "$NS" -o jsonpath='{.status.containerStatuses[0].restartCount}')" -eq "$BASE_RESTARTS"
echo "OK 4 - failed readiness removes traffic without restarting the container"

kubectl exec moody -n "$NS" -- touch /tmp/ready
kubectl wait -n "$NS" --for=condition=Ready pod/moody --timeout=90s >/dev/null
test -n "$(kubectl get endpoints moody -n "$NS" -o jsonpath='{.subsets[0].addresses[0].ip}')"
echo "OK 5 - restoring readiness returns the same Pod to Service traffic"

docker cp "$DIR/static-hello.yaml" "$NODE:$STATIC_PATH" >/dev/null
STATIC_POD="hello-static-$NODE"
waited=0
until kubectl get pod "$STATIC_POD" -n "$NS" >/dev/null 2>&1; do
  sleep 2
  waited=$((waited + 2))
  if [ "$waited" -ge 90 ]; then
    echo "ERROR: timed out waiting for the static Pod mirror" >&2
    exit 1
  fi
done
test "$(kubectl get pod "$STATIC_POD" -n "$NS" -o jsonpath='{.spec.nodeName}')" = "$NODE"
echo "OK 6 - placing a manifest on the node creates a static Pod without apply"

UID_BEFORE=$(kubectl get pod "$STATIC_POD" -n "$NS" -o jsonpath='{.metadata.uid}')
kubectl delete pod "$STATIC_POD" -n "$NS" --wait=false >/dev/null
waited=0
while true; do
  UID_AFTER=$(kubectl get pod "$STATIC_POD" -n "$NS" -o jsonpath='{.metadata.uid}' 2>/dev/null || true)
  if [ -n "$UID_AFTER" ] && [ "$UID_AFTER" != "$UID_BEFORE" ]; then break; fi
  sleep 2
  waited=$((waited + 2))
  if [ "$waited" -ge 90 ]; then
    echo "ERROR: timed out waiting for kubelet resurrection" >&2
    exit 1
  fi
done
echo "OK 7 - deleting the mirror bites: the kubelet republishes it with a new UID"

docker exec "$NODE" rm -f "$STATIC_PATH"
waited=0
while kubectl get pod "$STATIC_POD" -n "$NS" >/dev/null 2>&1; do
  sleep 2
  waited=$((waited + 2))
  if [ "$waited" -ge 90 ]; then
    echo "ERROR: timed out waiting for static Pod removal" >&2
    exit 1
  fi
done
echo "OK 8 - removing the node manifest removes the static Pod"

cleanup
kubectl wait --for=delete namespace/"$NS" --timeout=120s >/dev/null
if docker exec "$NODE" test -e "$STATIC_PATH"; then
  echo "UNEXPECTED: static manifest survived cleanup" >&2
  exit 1
fi
echo "OK 9 - Pods, Service, namespace, and node manifest were removed"

echo
echo "ALL CHECKS PASSED"
