#!/usr/bin/env bash
set -euo pipefail

# Chapter 7 solution — the declarative model seen live: kill a Pod, watch the
# controller resurrect it. Needs a reachable cluster (see SETUP.md) and
# kubectl; works on kind, minikube or any conformant cluster.

DEPLOY=lab-cap07

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — create one first (see SETUP.md)" >&2
  exit 1
}

cleanup() {
  kubectl delete deployment "$DEPLOY" --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

echo "== 1. The cluster answers =="
kubectl get nodes -o wide

echo
echo "== 2. The brain, in the system namespace =="
kubectl get pods -n kube-system

echo
echo "== 3. Declaring a desired state: 2 sleeping replicas =="
kubectl create deployment "$DEPLOY" --replicas=2 --image=alpine:3 -- sleep infinity
kubectl rollout status deployment/"$DEPLOY" --timeout=180s
kubectl get pods -l app="$DEPLOY" -o wide

echo
echo "== 4. The sabotage: delete one Pod, the loop replaces it =="
VICTIM=$(kubectl get pods -l app="$DEPLOY" -o jsonpath='{.items[0].metadata.name}')
echo "victim: $VICTIM"
kubectl delete pod "$VICTIM" --wait=true
kubectl rollout status deployment/"$DEPLOY" --timeout=180s
echo "--- pods after the sabotage (same count, one new name) ---"
kubectl get pods -l app="$DEPLOY"
if kubectl get pods -l app="$DEPLOY" -o name | grep -q "$VICTIM"; then
  echo "ERROR: the victim is still there?!" >&2
  exit 1
fi
echo "(the victim is gone, a replacement was born: observed state was pushed"
echo " back to the desired state, with no human intervention)"

echo
echo "== 5. Desired vs observed, in the same object =="
kubectl get deployment "$DEPLOY" \
  -o jsonpath='desired: spec.replicas={.spec.replicas}  observed: status.readyReplicas={.status.readyReplicas}{"\n"}'

echo
echo "== 6. Everything is a resource =="
RESOURCES=$(kubectl api-resources)
head -8 <<< "$RESOURCES"
echo "..."
kubectl get events --sort-by=.metadata.creationTimestamp | tail -5
