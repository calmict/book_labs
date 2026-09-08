#!/usr/bin/env bash
set -euo pipefail

# Proves the kubectl-to-process relay, ownership, and both self-healing loops.
# Requires a reachable cluster and a Docker-hosted node; creates only a
# throwaway namespace and never changes the node or cluster configuration.

DIR=$(cd "$(dirname "$0")" && pwd)
NS=book-lab-cap13

kubectl get nodes >/dev/null
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec "$NODE" true 2>/dev/null || {
  echo "ERROR: the node must be reachable with docker exec" >&2
  exit 1
}

cleanup() {
  kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup
kubectl create namespace "$NS" >/dev/null

kubectl -n "$NS" apply -f "$DIR/relay.yaml" >/dev/null
kubectl -n "$NS" rollout status deployment/relay --timeout=180s >/dev/null
EVENTS=$(kubectl -n "$NS" get events -o custom-columns='SIGNER:.source.component,REASON:.reason,OBJECT:.involvedObject.name')
for signature in deployment-controller replicaset-controller default-scheduler kubelet; do
  grep -q "$signature" <<< "$EVENTS" || {
    echo "ERROR: missing event signature $signature" >&2
    exit 1
  }
done
echo "OK 1 - events contain all four relay signatures"

POD=$(kubectl -n "$NS" get pod -l app=relay -o jsonpath='{.items[0].metadata.name}')
RS=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.metadata.ownerReferences[0].name}')
DEP=$(kubectl -n "$NS" get rs "$RS" -o jsonpath='{.metadata.ownerReferences[0].name}')
[ "$DEP" = relay ] || { echo "ERROR: broken ownership chain" >&2; exit 1; }
echo "OK 2 - ownerReferences link Pod to ReplicaSet to Deployment"

# The Pod decides the node, not the node list: on a multi-node cluster the first
# node is rarely the one running relay, and crictl would look in the wrong place.
NODE=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.nodeName}')
CID=$(docker exec "$NODE" crictl ps --name relay -q | head -1)
PID=$(docker exec "$NODE" crictl inspect -o go-template --template '{{.info.pid}}' "$CID")
CGROUP=$(docker exec "$NODE" cat "/proc/$PID/cgroup")
PIDNS=$(docker exec "$NODE" readlink "/proc/$PID/ns/pid")
if ! grep -q kubepods <<< "$CGROUP" || ! grep -q '^pid:\[' <<< "$PIDNS"; then
  echo "ERROR: process evidence does not show kubepods and a PID namespace" >&2
  exit 1
fi
echo "OK 3 - the container is a Linux process in kubepods and a PID namespace"

docker exec "$NODE" kill -9 "$PID"
for _ in $(seq 1 60); do
  RESTARTS=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || true)
  [ "${RESTARTS:-0}" -ge 1 ] && break
  sleep 2
done
[ "${RESTARTS:-0}" -ge 1 ] || { echo "ERROR: kubelet did not restart the container" >&2; exit 1; }
echo "OK 4 - killing the process keeps the Pod and increments restartCount"

kubectl -n "$NS" delete pod "$POD" --wait=false >/dev/null
for _ in $(seq 1 90); do
  NEWPOD=$(kubectl -n "$NS" get pod -l app=relay -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null || true)
  [ -n "$NEWPOD" ] && [ "$NEWPOD" != "$POD" ] && break
  sleep 2
done
if [ -z "${NEWPOD:-}" ] || [ "$NEWPOD" = "$POD" ]; then
  echo "ERROR: ReplicaSet did not replace the deleted Pod" >&2
  exit 1
fi
echo "OK 5 - deleting the Pod produces a new name through reconciliation"
echo "ALL CHECKS PASSED"
