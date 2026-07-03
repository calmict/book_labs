#!/usr/bin/env bash
set -euo pipefail

# Chapter 12 solution — probes, restarts, and the pod that resurrects alone.
# Needs a reachable cluster whose node is a Docker container (kind, or
# minikube with the docker driver).

DIR=$(cd "$(dirname "$0")" && pwd)

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec "$NODE" true 2>/dev/null || {
  echo "ERROR: cannot enter node $NODE with docker exec (this run.sh needs" >&2
  echo " kind, or minikube with the docker driver)" >&2
  exit 1
}

cleanup() {
  kubectl delete pod liar moody --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete service moody --ignore-not-found >/dev/null 2>&1 || true
  docker exec "$NODE" rm -f /etc/kubernetes/manifests/static-hello.yaml 2>/dev/null || true
}
trap cleanup EXIT
cleanup

echo "== 1. The lying app: liveness at work =="
kubectl apply -f "$DIR/pod-liar.yaml"
echo -n "waiting for the doctor to intervene (restarts >= 2) "
waited=0
while true; do
  RC=$(kubectl get pod liar -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
  if [ -n "$RC" ] && [ "$RC" -ge 2 ]; then break; fi
  echo -n "."
  sleep 5
  waited=$((waited + 5))
  if [ "$waited" -ge 240 ]; then
    echo " timeout" >&2
    exit 1
  fi
done
echo " restarts=$RC"
kubectl describe pod liar | grep -E 'Unhealthy|Killing|Back-off' | tail -4

echo
echo "== 2. The moody patient: readiness gates the traffic =="
kubectl apply -f "$DIR/pod-moody.yaml"
kubectl wait --for=condition=Ready pod/moody --timeout=120s >/dev/null
echo "--- endpoints while healthy ---"
kubectl get endpoints moody
kubectl exec moody -- rm /tmp/ready
echo -n "waiting for the bench "
waited=0
until [ -z "$(kubectl get endpoints moody -o jsonpath='{.subsets[0].addresses}' 2>/dev/null)" ]; do
  echo -n "."
  sleep 3
  waited=$((waited + 3))
  if [ "$waited" -ge 90 ]; then
    echo " timeout" >&2
    exit 1
  fi
done
echo
echo "--- endpoints while sick (empty), and NO restart ---"
kubectl get endpoints moody
kubectl get pod moody
kubectl exec moody -- touch /tmp/ready
waited=0
until [ -n "$(kubectl get endpoints moody -o jsonpath='{.subsets[0].addresses}' 2>/dev/null)" ]; do
  sleep 3
  waited=$((waited + 3))
  if [ "$waited" -ge 90 ]; then
    echo "timeout waiting for recovery" >&2
    exit 1
  fi
done
echo "--- back in the game ---"
kubectl get endpoints moody

echo
echo "== 3. The kubelet needs nobody: static pods =="
echo "--- the static manifests already on the node (recognise the tenants?) ---"
docker exec "$NODE" ls /etc/kubernetes/manifests
docker cp "$DIR/../start/static-hello.yaml" "$NODE:/etc/kubernetes/manifests/" >/dev/null
echo -n "waiting for hello-static-$NODE "
waited=0
until kubectl get pod "hello-static-$NODE" >/dev/null 2>&1; do
  echo -n "."
  sleep 2
  waited=$((waited + 2))
  if [ "$waited" -ge 90 ]; then
    echo " timeout" >&2
    exit 1
  fi
done
echo
kubectl get pod "hello-static-$NODE"

echo
echo "== 4. Resurrection without a controller =="
U1=$(kubectl get pod "hello-static-$NODE" -o jsonpath='{.metadata.uid}')
kubectl delete pod "hello-static-$NODE" --wait=false >/dev/null
echo -n "deleted from the API; waiting for the kubelet's mirror to return "
waited=0
while true; do
  U2=$(kubectl get pod "hello-static-$NODE" -o jsonpath='{.metadata.uid}' 2>/dev/null || true)
  if [ -n "$U2" ] && [ "$U2" != "$U1" ]; then break; fi
  echo -n "."
  sleep 2
  waited=$((waited + 2))
  if [ "$waited" -ge 90 ]; then
    echo " timeout" >&2
    exit 1
  fi
done
echo
echo "(back with a new uid: the API object is just the kubelet's mirror)"
docker exec "$NODE" rm /etc/kubernetes/manifests/static-hello.yaml
waited=0
while kubectl get pod "hello-static-$NODE" >/dev/null 2>&1; do
  sleep 2
  waited=$((waited + 2))
  if [ "$waited" -ge 90 ]; then
    echo "timeout waiting for the static pod to vanish" >&2
    exit 1
  fi
done
echo "(file removed, pod gone: the file IS the pod)"
