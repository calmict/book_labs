#!/usr/bin/env bash
# Chapter 20 - solution test. Proves static one-to-one PV/PVC binding,
# dynamic provisioning through the default StorageClass, and the contrasting
# Retain/Delete reclaim policies. Uses an isolated namespace and never changes
# the protected cluster or its storage configuration.
set -euo pipefail

DIR=$(cd "$(dirname "$0")" && pwd)
NS=lab-cap20
NODE=""
DYNAMIC_PV=""

cleanup() {
  kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  kubectl delete pv manual-pv --ignore-not-found --wait=true >/dev/null 2>&1 || true
  if [ -n "$DYNAMIC_PV" ]; then
    kubectl delete pv "$DYNAMIC_PV" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  fi
  if [ -n "$NODE" ]; then
    docker exec "$NODE" rm -rf /tmp/manual-pv >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

command -v kubectl >/dev/null || { echo "ERROR: kubectl is required" >&2; exit 1; }
command -v docker >/dev/null || { echo "ERROR: Docker is required" >&2; exit 1; }
kubectl get nodes >/dev/null || { echo "ERROR: no reachable cluster" >&2; exit 1; }
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
if ! docker exec "$NODE" true >/dev/null 2>&1; then
  echo "ERROR: node $NODE is not a Docker container; use kind or minikube's Docker driver" >&2
  exit 1
fi
if ! kubectl get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' | grep -q .; then
  echo "ERROR: the cluster needs a default StorageClass for dynamic provisioning" >&2
  exit 1
fi
echo "PRECHECK cluster reachable, Docker-backed node available, default StorageClass present"

cleanup
kubectl create namespace "$NS" >/dev/null

pvc_phase() { kubectl -n "$NS" get pvc "$1" -o jsonpath='{.status.phase}' 2>/dev/null || true; }
wait_phase() {
  local pvc=$1 want=$2 waited=0
  until [ "$(pvc_phase "$pvc")" = "$want" ]; do
    sleep 2
    waited=$((waited + 2))
    if [ "$waited" -ge 120 ]; then
      echo "timeout: $pvc is '$(pvc_phase "$pvc")', wanted $want" >&2
      exit 1
    fi
  done
}

kubectl apply -f "$DIR/marriage.yaml" >/dev/null
wait_phase bride Bound
kubectl -n "$NS" wait --for=condition=Ready pod/writer --timeout=180s >/dev/null
bound_pv=$(kubectl -n "$NS" get pvc bride -o jsonpath='{.spec.volumeName}')
if [ "$bound_pv" != "manual-pv" ]; then
  echo "UNEXPECTED: bride bound to $bound_pv instead of manual-pv" >&2
  exit 1
fi
echo "OK 1 - the compatible static claim binds one-to-one to manual-pv"

kubectl apply -f "$DIR/../start/spinster.yaml" >/dev/null
sleep 5
if [ "$(pvc_phase spinster)" != "Pending" ]; then
  echo "UNEXPECTED: the second static claim is $(pvc_phase spinster), not Pending" >&2
  exit 1
fi
echo "OK 2 - the gate bites: a second claim stays Pending while the only PV is already bound"

kubectl apply -f "$DIR/dynamic.yaml" >/dev/null
wait_phase cloud Bound
kubectl -n "$NS" wait --for=condition=Ready pod/tenant --timeout=180s >/dev/null
DYNAMIC_PV=$(kubectl -n "$NS" get pvc cloud -o jsonpath='{.spec.volumeName}')
if [ -z "$DYNAMIC_PV" ] || [ "$DYNAMIC_PV" = "manual-pv" ]; then
  echo "UNEXPECTED: no distinct dynamically provisioned PV was recorded" >&2
  exit 1
fi
echo "OK 3 - the default StorageClass dynamically provisions $DYNAMIC_PV"

dynamic_policy=$(kubectl get pv "$DYNAMIC_PV" -o jsonpath='{.spec.persistentVolumeReclaimPolicy}')
manual_policy=$(kubectl get pv manual-pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}')
if [ "$dynamic_policy" != "Delete" ] || [ "$manual_policy" != "Retain" ]; then
  echo "UNEXPECTED: reclaim policies are dynamic=$dynamic_policy manual=$manual_policy" >&2
  exit 1
fi
echo "OK 4 - the two volumes declare contrasting Delete and Retain policies"

kubectl -n "$NS" delete pod writer tenant --wait=true >/dev/null
kubectl -n "$NS" delete pvc bride spinster cloud --wait=true >/dev/null
waited=0
while kubectl get pv "$DYNAMIC_PV" >/dev/null 2>&1; do
  sleep 2
  waited=$((waited + 2))
  if [ "$waited" -ge 120 ]; then
    echo "timeout: Delete did not remove $DYNAMIC_PV" >&2
    exit 1
  fi
done
echo "OK 5 - deleting the dynamic claim removes its Delete-policy PV"

phase=$(kubectl get pv manual-pv -o jsonpath='{.status.phase}')
dowry=$(docker exec "$NODE" cat /tmp/manual-pv/dote.txt)
if [ "$phase" != "Released" ] || [ "$dowry" != "dote" ]; then
  echo "UNEXPECTED: retained PV phase=$phase, stored data=$dowry" >&2
  exit 1
fi
echo "OK 6 - Retain leaves manual-pv Released and preserves the stored data"

echo
echo "ALL CHECKS PASSED"
