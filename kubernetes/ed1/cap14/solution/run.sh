#!/usr/bin/env bash
set -euo pipefail

# Proves Pod sharing, the pause sandbox, init ordering, and derived QoS.
# Requires a reachable cluster and a Docker-hosted node; creates only a
# throwaway namespace and reads process metadata without changing the node.

DIR=$(cd "$(dirname "$0")" && pwd)
NS=book-lab-cap14

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

# The incomplete manifest lacks writer: it must not satisfy the localhost test.
kubectl -n "$NS" apply -f "$DIR/../start/condo.yaml" >/dev/null
kubectl -n "$NS" wait --for=condition=Ready pod/condo --timeout=180s >/dev/null
if kubectl -n "$NS" exec condo -c writer -- true >/dev/null 2>&1; then
  echo "ERROR: incomplete condo unexpectedly contains the writer" >&2
  exit 1
fi
kubectl -n "$NS" delete pod condo --wait=true >/dev/null
kubectl -n "$NS" apply -f "$DIR/condo.yaml" >/dev/null
kubectl -n "$NS" wait --for=condition=Ready pod/condo --timeout=180s >/dev/null
for _ in $(seq 1 20); do
  PAGE=$(kubectl -n "$NS" exec condo -c writer -- wget -qO- http://localhost:8080 2>/dev/null || true)
  [ -n "$PAGE" ] && break
  sleep 1
done
[ -n "${PAGE:-}" ] || { echo "ERROR: localhost and shared volume test failed" >&2; exit 1; }
echo "OK 1 - the missing tenant bites, while the completed Pod shares localhost and data"

# The Pod decides the node, not the node list: on a multi-node cluster condo is
# rarely on the first node, and crictl would look in the wrong place.
NODE=$(kubectl -n "$NS" get pod condo -o jsonpath='{.spec.nodeName}')
W=$(docker exec "$NODE" crictl ps --name writer -q | head -1)
H=$(docker exec "$NODE" crictl ps --name web -q | head -1)
PW=$(docker exec "$NODE" crictl inspect -o go-template --template '{{.info.pid}}' "$W")
PH=$(docker exec "$NODE" crictl inspect -o go-template --template '{{.info.pid}}' "$H")
NETW=$(docker exec "$NODE" readlink "/proc/$PW/ns/net")
NETH=$(docker exec "$NODE" readlink "/proc/$PH/ns/net")
PIDW=$(docker exec "$NODE" readlink "/proc/$PW/ns/pid")
PIDH=$(docker exec "$NODE" readlink "/proc/$PH/ns/pid")
if [ "$NETW" != "$NETH" ] || [ "$PIDW" = "$PIDH" ]; then
  echo "ERROR: unexpected namespace sharing" >&2
  exit 1
fi
echo "OK 2 - tenants share the network namespace but not PID namespaces"

kubectl -n "$NS" apply -f "$DIR/condo-glass.yaml" >/dev/null
kubectl -n "$NS" wait --for=condition=Ready pod/condo-glass --timeout=180s >/dev/null
INSIDE=$(kubectl -n "$NS" exec condo-glass -c writer -- ps)
grep -Eq '[[:space:]]1[[:space:]].*/pause' <<< "$INSIDE" || {
  echo "ERROR: pause is not visible as PID 1" >&2
  exit 1
}
echo "OK 3 - the shared process namespace exposes pause as PID 1"

kubectl -n "$NS" apply -f "$DIR/init.yaml" >/dev/null
for _ in $(seq 1 20); do
  INIT=$(kubectl -n "$NS" get pod init-demo -o jsonpath='{.status.initContainerStatuses[0].state.running.startedAt}' 2>/dev/null || true)
  [ -n "$INIT" ] && break
  sleep 1
done
[ -n "${INIT:-}" ] || { echo "ERROR: init phase was not observed" >&2; exit 1; }
kubectl -n "$NS" wait --for=condition=Ready pod/init-demo --timeout=180s >/dev/null
[ "$(kubectl -n "$NS" logs init-demo -c app | head -1)" = ready ] || {
  echo "ERROR: app did not receive the init output" >&2
  exit 1
}
echo "OK 4 - the app starts only after the init container opens the gate"

kubectl -n "$NS" apply -f "$DIR/qos-trio.yaml" >/dev/null
POOR=$(kubectl -n "$NS" get pod poor -o jsonpath='{.status.qosClass}')
MIDDLE=$(kubectl -n "$NS" get pod middle -o jsonpath='{.status.qosClass}')
ROYAL=$(kubectl -n "$NS" get pod royal -o jsonpath='{.status.qosClass}')
[ "$POOR/$MIDDLE/$ROYAL" = BestEffort/Burstable/Guaranteed ] || {
  echo "ERROR: unexpected QoS classes: $POOR/$MIDDLE/$ROYAL" >&2
  exit 1
}
echo "OK 5 - resources derive BestEffort, Burstable, and Guaranteed"
echo "ALL CHECKS PASSED"
