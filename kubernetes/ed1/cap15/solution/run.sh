#!/usr/bin/env bash
set -euo pipefail

# Chapter 15 solution — the release, the disaster and the comeback.
# Pure API exercise: any reachable cluster will do.

DIR=$(cd "$(dirname "$0")" && pwd)

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}

cleanup() {
  kubectl delete deployment shop --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

echo "== 1. Opening the shop: alpine 3.19, three replicas =="
kubectl apply -f "$DIR/shop.yaml"
kubectl annotate deployment/shop kubernetes.io/change-cause="opening: alpine 3.19" >/dev/null
kubectl rollout status deployment/shop --timeout=240s >/dev/null
kubectl get pods -l app=shop

echo
echo "== 2. Who really rules: one ReplicaSet, hash-named =="
kubectl get replicaset -l app=shop

echo
echo "== 3. The release: rolling to alpine 3.20 =="
kubectl set image deployment/shop sleeper=alpine:3.20
kubectl annotate deployment/shop kubernetes.io/change-cause="release: alpine 3.20" >/dev/null
kubectl rollout status deployment/shop --timeout=240s
echo "--- two ReplicaSets now: the new one full, the old one kept at 0 ---"
kubectl get replicaset -l app=shop
kubectl rollout history deployment/shop

echo
echo "== 4. The disaster: a version that does not exist =="
kubectl set image deployment/shop sleeper=alpine:3.99
kubectl annotate deployment/shop kubernetes.io/change-cause="release: alpine 3.99 (oops)" >/dev/null
set +e
kubectl rollout status deployment/shop --timeout=30s
set -e
echo -n "waiting for the scout to hit the wall "
waited=0
until kubectl get pods -l app=shop --no-headers | grep -qE 'ImagePullBackOff|ErrImagePull'; do
  echo -n "."
  sleep 3
  waited=$((waited + 3))
  if [ "$waited" -ge 120 ]; then
    echo " timeout" >&2
    exit 1
  fi
done
echo
kubectl get pods -l app=shop
AVAILABLE=$(kubectl get deployment shop -o jsonpath='{.status.availableReplicas}')
if [ "$AVAILABLE" = "3" ]; then
  echo "(the rollout is stuck, yet 3 replicas of 3.20 are still serving:"
  echo " maxUnavailable 0 never let the old guard leave)"
else
  echo "WARNING: availableReplicas=$AVAILABLE, expected 3" >&2
fi

echo
echo "== 5. The comeback: one command =="
kubectl rollout undo deployment/shop
kubectl rollout status deployment/shop --timeout=240s >/dev/null
IMG=$(kubectl get deployment shop -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "image now: $IMG"
if [ "$IMG" != "alpine:3.20" ]; then
  echo "WARNING: expected alpine:3.20 after the undo" >&2
fi
kubectl rollout history deployment/shop
echo "(no magic: the 3.20 ReplicaSet was still there at zero, the undo just"
echo " scaled it back up — chapter 7's loop, wearing a release manager's hat)"
