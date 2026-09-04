#!/usr/bin/env bash
set -euo pipefail

# Proves ReplicaSet ownership, zero-downtime rollout, a biting broken
# release, and rollback. Uses only a throwaway namespace on any cluster.

DIR=$(cd "$(dirname "$0")" && pwd)
NS=book-lab-cap15

kubectl get nodes >/dev/null
cleanup() {
  kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup
kubectl create namespace "$NS" >/dev/null

kubectl -n "$NS" apply -f "$DIR/shop.yaml" >/dev/null
kubectl -n "$NS" annotate deployment/shop kubernetes.io/change-cause="opening: alpine 3.19" >/dev/null
kubectl -n "$NS" rollout status deployment/shop --timeout=240s >/dev/null
[ "$(kubectl -n "$NS" get deployment shop -o jsonpath='{.status.availableReplicas}')" = 3 ] || exit 1
echo "OK 1 - the opening ReplicaSet keeps three Pods available"

RS=$(kubectl -n "$NS" get pod -l app=shop -o jsonpath='{.items[0].metadata.ownerReferences[0].name}')
[ "$(kubectl -n "$NS" get rs "$RS" -o jsonpath='{.metadata.ownerReferences[0].kind}')" = Deployment ] || exit 1
echo "OK 2 - ownership divides Pod, ReplicaSet, and Deployment duties"

kubectl -n "$NS" set image deployment/shop sleeper=alpine:3.20 >/dev/null
kubectl -n "$NS" annotate deployment/shop kubernetes.io/change-cause="release: alpine 3.20" >/dev/null
kubectl -n "$NS" rollout status deployment/shop --timeout=240s >/dev/null
FULL=$(kubectl -n "$NS" get rs -l app=shop -o jsonpath='{range .items[*]}{.status.readyReplicas}{"\n"}{end}' | grep -c '^3$')
ZERO=$(kubectl -n "$NS" get rs -l app=shop -o jsonpath='{range .items[*]}{.spec.replicas}{"\n"}{end}' | grep -c '^0$')
[ "$FULL" -eq 1 ] && [ "$ZERO" -ge 1 ] || exit 1
echo "OK 3 - rolling update leaves one live and one historical ReplicaSet"

kubectl -n "$NS" set image deployment/shop sleeper=alpine:3.99 >/dev/null
kubectl -n "$NS" annotate deployment/shop kubernetes.io/change-cause="release: alpine 3.99 (oops)" >/dev/null
for _ in $(seq 1 60); do
  BROKEN=$(kubectl -n "$NS" get pods -l app=shop --no-headers 2>/dev/null | grep -cE 'ImagePullBackOff|ErrImagePull' || true)
  [ "$BROKEN" -ge 1 ] && break
  sleep 2
done
AVAILABLE=$(kubectl -n "$NS" get deployment shop -o jsonpath='{.status.availableReplicas}')
if [ "${BROKEN:-0}" -lt 1 ] || [ "$AVAILABLE" != 3 ]; then
  echo "ERROR: broken release did not bite while preserving three replicas" >&2
  exit 1
fi
echo "OK 4 - nonexistent image blocks the rollout but maxUnavailable keeps capacity"

kubectl -n "$NS" rollout undo deployment/shop >/dev/null
kubectl -n "$NS" rollout status deployment/shop --timeout=240s >/dev/null
IMAGE=$(kubectl -n "$NS" get deployment shop -o jsonpath='{.spec.template.spec.containers[0].image}')
[ "$IMAGE" = alpine:3.20 ] || { echo "ERROR: rollback returned $IMAGE" >&2; exit 1; }
echo "OK 5 - rollout undo restores the previous ReplicaSet template"
echo "ALL CHECKS PASSED"
