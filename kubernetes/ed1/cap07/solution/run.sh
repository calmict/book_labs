#!/usr/bin/env bash
# Chapter 7 verification - identifies the control plane, applies desired state,
# proves spec/status convergence, and deletes a Pod to test reconciliation.
# Requires kubectl and a reachable conformant cluster. Namespaced and throwaway.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
NS=lab-cap07

cleanup() {
  kubectl delete namespace "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster - see SETUP.md" >&2
  exit 1
}
cleanup
kubectl wait --for=delete namespace/"$NS" --timeout=120s >/dev/null 2>&1 || true
kubectl create namespace "$NS" >/dev/null

SYSTEM_PODS=$(kubectl get pods -n kube-system -o name)
for component in etcd kube-apiserver kube-controller-manager kube-scheduler; do
  grep -q "$component" <<< "$SYSTEM_PODS"
done
echo "OK 1 - the cluster exposes the four control-plane components"

kubectl apply -f "$HERE/deployment.yaml" >/dev/null
kubectl rollout status deployment/lab-cap07 -n "$NS" --timeout=180s >/dev/null
READY=$(kubectl get deployment lab-cap07 -n "$NS" -o jsonpath='{.status.readyReplicas}')
DESIRED=$(kubectl get deployment lab-cap07 -n "$NS" -o jsonpath='{.spec.replicas}')
test "$DESIRED" = 2 && test "$READY" = 2
echo "OK 2 - spec requests two replicas and status reports two ready replicas"

VICTIM=$(kubectl get pods -n "$NS" -l app=lab-cap07 -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$VICTIM" -n "$NS" --wait=true >/dev/null
for _ in $(seq 1 90); do
  CURRENT_READY=$(kubectl get deployment lab-cap07 -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
  CURRENT_PODS=$(kubectl get pods -n "$NS" -l app=lab-cap07 -o name)
  if [ "$CURRENT_READY" = 2 ] && [ "$(wc -l <<< "$CURRENT_PODS")" -eq 2 ]; then
    break
  fi
  sleep 2
done
PODS=$(kubectl get pods -n "$NS" -l app=lab-cap07 -o name)
test "${CURRENT_READY:-}" = 2
test "$(wc -l <<< "$PODS")" -eq 2
if grep -q "$VICTIM" <<< "$PODS"; then
  echo "UNEXPECTED: the deleted Pod still exists" >&2
  exit 1
fi
echo "OK 3 - the gate bites: deleting a Pod produces a different replacement"

API_RESOURCES=$(kubectl api-resources)
grep -q '^deployments[[:space:]]' <<< "$API_RESOURCES"
kubectl explain deployment.spec.replicas >/dev/null
echo "OK 4 - the API lists Deployments and explains spec.replicas"

cleanup
kubectl wait --for=delete namespace/"$NS" --timeout=120s >/dev/null
echo "OK 5 - the lab namespace and its objects were removed"

echo
echo "ALL CHECKS PASSED"
