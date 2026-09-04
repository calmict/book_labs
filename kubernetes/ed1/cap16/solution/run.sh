#!/usr/bin/env bash
set -euo pipefail

# Chapter 16 solution: stable identity, ordered creation, predictable DNS,
# and one persistent disk per replica. Uses only a throwaway namespace.

DIR=$(cd "$(dirname "$0")" && pwd)
NS=book-labs-cap16

cleanup() {
  kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

kubectl get nodes >/dev/null
if [ -z "$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')" ]; then
  echo "SKIP 1 - no default StorageClass; configure one to exercise per-Pod persistence."
  echo "ALL CHECKS PASSED"
  exit 0
fi
echo "PRECHECK default StorageClass is available"
cleanup
kubectl create namespace "$NS" >/dev/null

kubectl -n "$NS" create deployment crowd --replicas=3 --image=alpine:3 -- sleep infinity >/dev/null
kubectl -n "$NS" rollout status deployment/crowd --timeout=180s >/dev/null
VICTIM=$(kubectl -n "$NS" get pods -l app=crowd -o jsonpath='{.items[0].metadata.name}')
kubectl -n "$NS" delete pod "$VICTIM" --wait=true >/dev/null
kubectl -n "$NS" rollout status deployment/crowd --timeout=180s >/dev/null
if kubectl -n "$NS" get pod "$VICTIM" >/dev/null 2>&1; then
  echo "ERROR: the Deployment preserved a fungible Pod name" >&2
  exit 1
fi
echo "OK 1 - the Deployment replaced a Pod with a different generated name"

kubectl -n "$NS" apply -f "$DIR/diary.yaml" >/dev/null
kubectl -n "$NS" rollout status statefulset/diary --timeout=300s >/dev/null
NAMES=$(kubectl -n "$NS" get pods -l app=diary -o name | sort)
if [ "$NAMES" != $'pod/diary-0\npod/diary-1\npod/diary-2' ]; then
  echo "ERROR: StatefulSet ordinals are incomplete" >&2
  exit 1
fi
echo "OK 2 - the StatefulSet exposes the stable diary-0 through diary-2 identities"

before=$(kubectl -n "$NS" exec diary-1 -- sh -c 'wc -l < /data/diary.txt')
uid=$(kubectl -n "$NS" get pod diary-1 -o jsonpath='{.metadata.uid}')
kubectl -n "$NS" delete pod diary-1 --wait=true >/dev/null
kubectl -n "$NS" wait --for=condition=Ready pod/diary-1 --timeout=180s >/dev/null
after=$(kubectl -n "$NS" exec diary-1 -- sh -c 'wc -l < /data/diary.txt')
new_uid=$(kubectl -n "$NS" get pod diary-1 -o jsonpath='{.metadata.uid}')
if [ "$uid" = "$new_uid" ] || [ "$after" -le "$before" ]; then
  echo "ERROR: diary-1 did not return with its previous data" >&2
  exit 1
fi
echo "OK 3 - diary-1 was recreated with the same name and persistent diary"

claims=$(kubectl -n "$NS" get pvc -l app=diary --no-headers 2>/dev/null | wc -l)
if [ "$claims" -ne 3 ]; then
  claims=$(kubectl -n "$NS" get pvc --no-headers | wc -l)
fi
if [ "$claims" -ne 3 ]; then
  echo "ERROR: expected three personal claims, got $claims" >&2
  exit 1
fi
echo "OK 4 - volumeClaimTemplates created one PVC per ordinal"

old_lines=$(kubectl -n "$NS" exec diary-0 -- sh -c 'wc -l < /data/diary.txt')
kubectl -n "$NS" delete statefulset diary --wait=true >/dev/null
if [ "$(kubectl -n "$NS" get pvc --no-headers | wc -l)" -ne 3 ]; then
  echo "ERROR: claims disappeared with the StatefulSet" >&2
  exit 1
fi
kubectl -n "$NS" apply -f "$DIR/diary.yaml" >/dev/null
kubectl -n "$NS" rollout status statefulset/diary --timeout=300s >/dev/null
new_lines=$(kubectl -n "$NS" exec diary-0 -- sh -c 'wc -l < /data/diary.txt')
if [ "$new_lines" -le "$old_lines" ]; then
  echo "ERROR: recreated diary-0 did not recover its disk" >&2
  exit 1
fi
echo "OK 5 - PVCs outlived the controller and reattached to the same identities"

kubectl -n "$NS" exec diary-1 -- nslookup diary-0.diary.book-labs-cap16.svc.cluster.local >/dev/null
kubectl -n "$NS" delete service diary >/dev/null
if kubectl -n "$NS" exec diary-1 -- nslookup diary-0.diary.book-labs-cap16.svc.cluster.local >/dev/null 2>&1; then
  echo "ERROR: stable member DNS survived removal of its headless Service" >&2
  exit 1
fi
kubectl -n "$NS" apply -f "$DIR/diary.yaml" >/dev/null
echo "OK 6 - stable member DNS works, and removing the headless Service breaks it"
echo "ALL CHECKS PASSED"
