#!/usr/bin/env bash
set -euo pipefail

# Chapter 13 solution — the investigation: who touched my pod?
# Needs a cluster whose node is a Docker container (kind, or minikube on
# the docker driver): step 5 descends down to the Linux process.

DIR=$(cd "$(dirname "$0")" && pwd)

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}
FIRSTNODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec "$FIRSTNODE" true 2>/dev/null || {
  echo "ERROR: cannot enter node $FIRSTNODE with docker exec (this run.sh" >&2
  echo " needs kind, or minikube with the docker driver)" >&2
  exit 1
}

cleanup() {
  kubectl delete deployment relay --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

echo "== 2. The fact: one apply =="
kubectl apply -f "$DIR/relay.yaml"
kubectl rollout status deployment/relay --timeout=180s >/dev/null

echo
echo "== 3. The four signatures, in chronological order =="
kubectl get events --sort-by=.metadata.creationTimestamp \
  -o custom-columns='TIME:.metadata.creationTimestamp,SIGNATURE:.source.component,REASON:.reason,OBJECT:.involvedObject.name' \
  | grep -E 'SIGNATURE|relay'

echo
echo "== 4. The chain of ownership =="
kubectl get deployment,replicaset,pod -l app=relay
POD=$(kubectl get pod -l app=relay -o jsonpath='{.items[0].metadata.name}')
RS=$(kubectl get pod "$POD" -o jsonpath='{.metadata.ownerReferences[0].name}')
DEP=$(kubectl get rs "$RS" -o jsonpath='{.metadata.ownerReferences[0].name}')
echo "chain: pod/$POD -> replicaset/$RS -> deployment/$DEP"

echo
echo "== 5. Below the API, down to the process =="
NODE=$(kubectl get pod "$POD" -o jsonpath='{.spec.nodeName}')
CID=$(docker exec "$NODE" crictl ps --name relay -q)
PID=$(docker exec "$NODE" crictl inspect -o go-template --template '{{.info.pid}}' "$CID")
echo "container: ${CID:0:13}...  pid on the node: $PID"
echo "--- its cgroup (recognise kubepods, and the QoS class in the path?) ---"
docker exec "$NODE" cat "/proc/$PID/cgroup"
echo "--- its pid namespace (chapter 2 sends its regards) ---"
docker exec "$NODE" readlink "/proc/$PID/ns/pid"

echo
echo "== 6. Two deaths, two doctors =="
docker exec "$NODE" kill -9 "$PID"
echo -n "process killed behind the API's back; waiting for the kubelet "
waited=0
while true; do
  RC=$(kubectl get pod "$POD" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
  if [ -n "$RC" ] && [ "$RC" -ge 1 ]; then break; fi
  echo -n "."
  sleep 3
  waited=$((waited + 3))
  if [ "$waited" -ge 120 ]; then
    echo " timeout" >&2
    exit 1
  fi
done
echo
kubectl get pods -l app=relay
echo "(same pod, RESTARTS up: the kubelet's cure, PLEG-powered)"
kubectl delete pod "$POD" >/dev/null
kubectl rollout status deployment/relay --timeout=180s >/dev/null
NEWPOD=$(kubectl get pod -l app=relay -o jsonpath='{.items[0].metadata.name}')
kubectl get pods -l app=relay
if [ "$NEWPOD" = "$POD" ]; then
  echo "WARNING: same pod name after delete?!" >&2
else
  echo "(new name: the ReplicaSet controller's cure — two deaths, two doctors)"
fi
