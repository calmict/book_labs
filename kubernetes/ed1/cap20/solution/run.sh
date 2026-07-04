#!/usr/bin/env bash
set -euo pipefail

# Chapter 20 solution — the arranged marriage, the spinster, the automatic
# matchmaker and the two deaths. Needs a cluster with a default
# StorageClass and node access via docker exec (kind, or minikube on the
# docker driver).

DIR=$(cd "$(dirname "$0")" && pwd)

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec "$NODE" true 2>/dev/null || {
  echo "ERROR: cannot enter node $NODE with docker exec (this run.sh" >&2
  echo " needs kind, or minikube with the docker driver)" >&2
  exit 1
}

cleanup() {
  kubectl delete pod writer tenant --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete pvc bride spinster cloud --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete pv manual-pv --ignore-not-found >/dev/null 2>&1 || true
  docker exec "$NODE" rm -rf /tmp/manual-pv 2>/dev/null || true
}
trap cleanup EXIT
cleanup

pvc_phase() { kubectl get pvc "$1" -o jsonpath='{.status.phase}' 2>/dev/null; }

wait_phase() {
  local pvc=$1 want=$2 waited=0
  until [ "$(pvc_phase "$pvc")" = "$want" ]; do
    sleep 3
    waited=$((waited + 3))
    if [ "$waited" -ge 120 ]; then
      echo "timeout: $pvc is '$(pvc_phase "$pvc")', wanted $want" >&2
      exit 1
    fi
  done
}

echo "== 1. The arranged marriage =="
kubectl apply -f "$DIR/marriage.yaml"
wait_phase bride Bound
kubectl wait --for=condition=Ready pod/writer --timeout=180s >/dev/null
kubectl get pv manual-pv
kubectl get pvc bride
echo "(bride Bound to manual-pv; the writer is storing the dowry)"

echo
echo "== 2. The spinster =="
kubectl apply -f "$DIR/../start/spinster.yaml"
sleep 5
kubectl get pvc spinster
if [ "$(pvc_phase spinster)" = "Pending" ]; then
  echo "(Pending forever: binding is 1:1 and the manual volumes are gone)"
else
  echo "WARNING: spinster is $(pvc_phase spinster), expected Pending" >&2
fi

echo
echo "== 3. The automatic matchmaker =="
kubectl apply -f "$DIR/dynamic.yaml"
wait_phase cloud Bound
kubectl get pvc cloud
echo "--- a volume born out of nowhere, signed by the provisioner ---"
kubectl get pv
kubectl get storageclass
echo "(compare the RECLAIM POLICY columns: Retain vs Delete)"

echo
echo "== 4. Two different deaths =="
kubectl delete pod writer tenant >/dev/null
kubectl delete pvc bride spinster cloud >/dev/null
echo -n "waiting for the dynamic volume to vanish "
waited=0
until [ "$(kubectl get pv --no-headers 2>/dev/null | grep -c '^pvc-')" -eq 0 ]; do
  echo -n "."
  sleep 3
  waited=$((waited + 3))
  if [ "$waited" -ge 120 ]; then
    echo " timeout" >&2
    exit 1
  fi
done
echo
kubectl get pv
PHASE=$(kubectl get pv manual-pv -o jsonpath='{.status.phase}')
if [ "$PHASE" = "Released" ]; then
  echo "(the dynamic one died with its claim; manual-pv is a widow: Released,"
  echo " not remarriable — the late claim's claimRef is still engraved)"
else
  echo "WARNING: manual-pv is $PHASE, expected Released" >&2
fi
echo "--- but the dowry survived (Retain kept its promise) ---"
docker exec "$NODE" cat /tmp/manual-pv/dote.txt
