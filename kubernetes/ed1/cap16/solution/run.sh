#!/usr/bin/env bash
set -euo pipefail

# Chapter 16 solution — names, order, and disks that outlive everything.
# Pure API exercise: any cluster with a default StorageClass will do.

DIR=$(cd "$(dirname "$0")" && pwd)

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}

cleanup() {
  kubectl delete statefulset diary --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete service diary --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete deployment crowd --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete pvc data-diary-0 data-diary-1 data-diary-2 \
    --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

wait_ready() {
  local pod=$1 waited=0
  until kubectl get pod "$pod" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null | grep -q true; do
    sleep 3
    waited=$((waited + 3))
    if [ "$waited" -ge 180 ]; then
      echo "timeout waiting for $pod" >&2
      exit 1
    fi
  done
}

echo "== 1. The crowd: fungible individuals =="
kubectl create deployment crowd --replicas=3 --image=alpine:3 -- sleep infinity
kubectl rollout status deployment/crowd --timeout=180s >/dev/null
kubectl get pods -l app=crowd
VICTIM=$(kubectl get pods -l app=crowd -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$VICTIM" >/dev/null
kubectl rollout status deployment/crowd --timeout=180s >/dev/null
echo "--- $VICTIM deleted; the replacement has another random name ---"
kubectl get pods -l app=crowd

echo
echo "== 2. The registry office: diary-0, THEN diary-1, THEN diary-2 =="
kubectl apply -f "$DIR/diary.yaml"
kubectl rollout status statefulset/diary --timeout=300s
kubectl get pods -l app=diary

echo
echo "== 3. Rebirth with the same name (and the same disk) =="
kubectl delete pod diary-1 >/dev/null
wait_ready diary-1
echo "--- diary-1 is back AS diary-1, and remembers its previous life ---"
kubectl exec diary-1 -- cat /data/diary.txt

echo
echo "== 4. One disk each =="
kubectl get pvc

echo
echo "== 5. The disk outlives even the controller =="
kubectl delete statefulset diary >/dev/null
sleep 3
echo "--- pods going or gone, but the claims stay ---"
kubectl get pvc
kubectl apply -f "$DIR/diary.yaml" >/dev/null
kubectl rollout status statefulset/diary --timeout=300s >/dev/null
echo "--- diary-0 recreated: its whole past is still on the disk ---"
kubectl exec diary-0 -- cat /data/diary.txt
LINES=$(kubectl exec diary-0 -- sh -c 'wc -l < /data/diary.txt')
if [ "$LINES" -ge 2 ]; then
  echo "($LINES lines: one per life — the data made a pact with nobody)"
else
  echo "WARNING: expected at least 2 diary lines, got $LINES" >&2
fi

echo
echo "== 6. The predictable address =="
kubectl exec diary-1 -- nslookup diary-0.diary.default.svc.cluster.local 2>&1 | tail -3
echo "(a stable DNS name per identity: how quorum members find each other)"
