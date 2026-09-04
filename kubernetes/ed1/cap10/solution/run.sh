#!/usr/bin/env bash
# Chapter 10 verification - observes a real leader-election Lease, runs a
# polling controller, checks repair and pruning, and contrasts two copies.
# Requires kubectl and a reachable cluster. Namespaced and throwaway.
set -euo pipefail

NS=cap10-lab
DIR=$(cd "$(dirname "$0")" && pwd)
CTRL="$DIR/minictl.sh"
WORK=$(mktemp -d)
PIDS=""

cleanup() {
  if [ -n "$PIDS" ]; then
    for pid in $PIDS; do
      kill -- "-$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    done
  fi
  kubectl delete namespace "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster - see chapter 7" >&2
  exit 1
}
kubectl delete namespace "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
kubectl wait --for=delete namespace/"$NS" --timeout=120s >/dev/null 2>&1 || true
kubectl create namespace "$NS" >/dev/null
echo "PRECHECK cluster is reachable; using namespace $NS"

total() {
  kubectl get pods -n "$NS" -l app=minictl --no-headers 2>/dev/null | grep -cv Terminating || true
}

wait_total() {
  local want=$1 waited=0
  until [ "$(total)" -eq "$want" ]; do
    sleep 2
    waited=$((waited + 2))
    if [ "$waited" -ge 120 ]; then
      echo "ERROR: timed out waiting for $want Pods" >&2
      exit 1
    fi
  done
}

LEASE=kube-controller-manager
if kubectl get lease "$LEASE" -n kube-system >/dev/null 2>&1; then
  R1=$(kubectl get lease "$LEASE" -n kube-system -o jsonpath='{.spec.renewTime}')
  sleep 4
  R2=$(kubectl get lease "$LEASE" -n kube-system -o jsonpath='{.spec.renewTime}')
  test -n "$R1"
  test "$R1" != "$R2"
  echo "OK 1 - the controller-manager Lease renewTime advances"
else
  echo "SKIP 1 - this cluster exposes no controller-manager Lease; kind enables it, while some single-node distributions disable leader election"
fi

NAMESPACE="$NS" setsid bash "$CTRL" >"$WORK/controller.log" 2>&1 &
PIDS=$!
wait_total 2
echo "OK 2 - the completed controller converges from zero to two Pods"

VICTIM=$(kubectl get pods -n "$NS" -l app=minictl --no-headers | grep -v Terminating | awk 'NR==1 {print $1}')
kubectl delete pod "$VICTIM" -n "$NS" >/dev/null
wait_total 2
test "$(kubectl get pods -n "$NS" -l app=minictl --no-headers | wc -l)" -eq 2
echo "OK 3 - deleting one Pod triggers an automatic repair"

kubectl run minictl-extra -n "$NS" --labels=app=minictl --image=alpine:3 -- sleep infinity >/dev/null
wait_total 2
if kubectl get pod minictl-extra -n "$NS" >/dev/null 2>&1; then
  sleep 3
fi
test "$(total)" -eq 2
echo "OK 4 - injecting an excess Pod triggers automatic pruning"

kill -- "-$PIDS" 2>/dev/null || true
wait "$PIDS" 2>/dev/null || true
PIDS=""
VICTIM=$(kubectl get pods -n "$NS" -l app=minictl --no-headers | grep -v Terminating | awk 'NR==1 {print $1}')
kubectl delete pod "$VICTIM" -n "$NS" >/dev/null
sleep 4
test "$(total)" -eq 1
echo "OK 5 - the gate bites: without the controller, the deleted Pod stays missing"

kubectl delete pods -n "$NS" -l app=minictl --wait=true >/dev/null
NAMESPACE="$NS" setsid bash "$CTRL" >"$WORK/controller-a.log" 2>&1 &
PIDS=$!
NAMESPACE="$NS" setsid bash "$CTRL" >"$WORK/controller-b.log" 2>&1 &
PIDS="$PIDS $!"
wait_total 2
sleep 3
grep -q 'observed' "$WORK/controller-a.log"
grep -q 'observed' "$WORK/controller-b.log"
echo "OK 6 - two unelected copies both observe and act on the same desired state"

cleanup
PIDS=""
kubectl wait --for=delete namespace/"$NS" --timeout=120s >/dev/null
echo "OK 7 - controller processes, Pods, namespace, and temporary files were removed"

echo
echo "ALL CHECKS PASSED"
