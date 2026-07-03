#!/usr/bin/env bash
set -euo pipefail

# Chapter 14 solution — the condo pod: two tenants, one invisible janitor.
# Needs a cluster whose node is a Docker container (kind, or minikube on
# the docker driver): step 2 reads namespace inodes on the node.

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
  kubectl delete pod condo condo-glass init-demo poor middle royal \
    --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

echo "== 1. The condo: shared localhost, shared disk =="
kubectl apply -f "$DIR/condo.yaml"
kubectl wait --for=condition=Ready pod/condo --timeout=180s >/dev/null
sleep 3
PAGE=$(kubectl exec condo -c writer -- wget -qO- http://localhost:8080)
echo "the writer read, VIA LOCALHOST, the page served by the other tenant:"
echo "  $PAGE"
if [ -z "$PAGE" ]; then
  echo "ERROR: empty page" >&2
  exit 1
fi

echo
echo "== 2. The evidence from the node =="
NODE=$(kubectl get pod condo -o jsonpath='{.spec.nodeName}')
W=$(docker exec "$NODE" crictl ps --name writer -q)
H=$(docker exec "$NODE" crictl ps --name web -q)
PW=$(docker exec "$NODE" crictl inspect -o go-template --template '{{.info.pid}}' "$W")
PH=$(docker exec "$NODE" crictl inspect -o go-template --template '{{.info.pid}}' "$H")
NETW=$(docker exec "$NODE" readlink "/proc/$PW/ns/net")
NETH=$(docker exec "$NODE" readlink "/proc/$PH/ns/net")
PIDW=$(docker exec "$NODE" readlink "/proc/$PW/ns/pid")
PIDH=$(docker exec "$NODE" readlink "/proc/$PH/ns/pid")
echo "net ns:  writer $NETW / web $NETH"
echo "pid ns:  writer $PIDW / web $PIDH"
if [ "$NETW" = "$NETH" ] && [ "$PIDW" != "$PIDH" ]; then
  echo "(one shared network, two private process trees: the pod contract)"
else
  echo "WARNING: unexpected namespace layout" >&2
fi
echo "--- and who keeps those namespaces alive? the janitor ---"
docker exec "$NODE" ps -ef | grep '[/]pause' | head -2

echo
echo "== 3. The glass condo: the janitor seen from inside =="
kubectl apply -f "$DIR/condo-glass.yaml"
kubectl wait --for=condition=Ready pod/condo-glass --timeout=180s >/dev/null
INSIDE=$(kubectl exec condo-glass -c writer -- ps aux)
echo "$INSIDE"
if grep -q pause <<< "$INSIDE"; then
  echo "(there it is: /pause as PID 1, seen without leaving the pod)"
else
  echo "WARNING: pause not visible from inside" >&2
fi

echo
echo "== 4. The gatekeeper: Init phase, live =="
kubectl apply -f "$DIR/init.yaml"
sleep 3
kubectl get pod init-demo
kubectl wait --for=condition=Ready pod/init-demo --timeout=180s >/dev/null
kubectl get pod init-demo
kubectl logs init-demo -c app | head -1

echo
echo "== 5. The three castes =="
kubectl apply -f "$DIR/qos-trio.yaml"
sleep 2
kubectl get pod poor middle royal \
  -o custom-columns='POD:.metadata.name,QOS:.status.qosClass'
if [ "$(kubectl get pod royal -o jsonpath='{.status.qosClass}')" != "Guaranteed" ]; then
  echo "WARNING: royal is not Guaranteed?!" >&2
fi
echo "(you never declared the class: the apiserver deduced it from the"
echo " resources — and chapter 13 showed you the cgroup folder it becomes)"
