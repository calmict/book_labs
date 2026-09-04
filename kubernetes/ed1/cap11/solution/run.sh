#!/usr/bin/env bash
# Chapter 11 verification - creates an isolated three-node kind cluster and
# checks scheduling, direct node assignment, filtering, anti-affinity, and a
# matching toleration. The dedicated cluster is removed when this run created it.
set -euo pipefail

CLUSTER=book-labs-sched
NS=cap11-lab
DIR=$(cd "$(dirname "$0")" && pwd)
CREATED=0
PREV_CTX=$(kubectl config current-context 2>/dev/null || true)

kc() {
  kubectl --context "kind-$CLUSTER" "$@"
}

cleanup() {
  if [ "$CREATED" -eq 1 ]; then
    kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
    if [ -n "$PREV_CTX" ] && [ "$PREV_CTX" != "kind-$CLUSTER" ]; then
      kubectl config use-context "$PREV_CTX" >/dev/null 2>&1 || true
    fi
  else
    kc delete namespace "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
    kc label node "$CLUSTER-worker" disk- >/dev/null 2>&1 || true
    kc label node "$CLUSTER-worker2" disk- >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

command -v kind >/dev/null || {
  echo "ERROR: kind is required for the three-node scheduling topology" >&2
  exit 1
}
docker info >/dev/null 2>&1 || {
  echo "ERROR: Docker is required to create the dedicated kind cluster" >&2
  exit 1
}

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "PRECHECK reusing dedicated cluster $CLUSTER"
else
  echo "PRECHECK creating dedicated three-node cluster $CLUSTER"
  kind create cluster --config "$DIR/../start/kind-workers.yaml" --wait 180s
  CREATED=1
fi
kc wait --for=condition=Ready nodes --all --timeout=180s >/dev/null
test "$(kc get nodes --no-headers | wc -l)" -eq 3
echo "OK 1 - the dedicated cluster has one control plane and two workers"

kc delete namespace "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
kc wait --for=delete namespace/"$NS" --timeout=120s >/dev/null 2>&1 || true
kc create namespace "$NS" >/dev/null
kc label node "$CLUSTER-worker" disk- >/dev/null 2>&1 || true
kc label node "$CLUSTER-worker2" disk- >/dev/null 2>&1 || true

kc run witness -n "$NS" --image=alpine:3 -- sleep infinity >/dev/null
kc wait -n "$NS" --for=condition=Ready pod/witness --timeout=180s >/dev/null
test -n "$(kc get pod witness -n "$NS" -o jsonpath='{.spec.nodeName}')"
kc get events -n "$NS" --field-selector involvedObject.name=witness -o jsonpath='{range .items[*]}{.reason}{"\n"}{end}' | grep -qx Scheduled
echo "OK 2 - the scheduler chooses a node and records a Scheduled event"

kc apply -n "$NS" -f "$DIR/pod-bypass.yaml" >/dev/null
kc wait -n "$NS" --for=condition=Ready pod/bypass --timeout=180s >/dev/null
test "$(kc get pod bypass -n "$NS" -o jsonpath='{.spec.nodeName}')" = "$CLUSTER-worker"
if kc get events -n "$NS" --field-selector involvedObject.name=bypass -o jsonpath='{range .items[*]}{.reason}{"\n"}{end}' | grep -qx Scheduled; then
  echo "UNEXPECTED: bypass received a Scheduled event" >&2
  exit 1
fi
echo "OK 3 - nodeName bypasses the scheduler while the worker kubelet runs the Pod"

kc apply -n "$NS" -f "$DIR/pod-picky.yaml" >/dev/null
sleep 6
test "$(kc get pod picky -n "$NS" -o jsonpath='{.status.phase}')" = Pending
kc get events -n "$NS" --field-selector involvedObject.name=picky -o jsonpath='{range .items[*]}{.reason}{" "}{.message}{"\n"}{end}' | grep -q 'FailedScheduling.*affinity/selector'
echo "OK 4 - the gate bites: without disk=ssd, filtering leaves picky Pending"

kc label node "$CLUSTER-worker2" disk=ssd >/dev/null
kc wait -n "$NS" --for=condition=Ready pod/picky --timeout=180s >/dev/null
test "$(kc get pod picky -n "$NS" -o jsonpath='{.spec.nodeName}')" = "$CLUSTER-worker2"
echo "OK 5 - adding the required label admits picky onto the matching worker"

kc apply -n "$NS" -f "$DIR/deploy-spread.yaml" >/dev/null
kc rollout status deployment/spread -n "$NS" --timeout=180s >/dev/null
NODES=$(kc get pods -n "$NS" -l app=spread -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l)
test "$NODES" -eq 2
echo "OK 6 - required anti-affinity spreads two replicas across two workers"

kc scale deployment spread -n "$NS" --replicas=3 >/dev/null
sleep 6
PENDING=$(kc get pods -n "$NS" -l app=spread -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' | grep -c '^Pending$' || true)
test "$PENDING" -eq 1
echo "OK 7 - the gate bites: anti-affinity plus the taint leaves replica three Pending"

kc apply -n "$NS" -f "$DIR/deploy-spread-tolerated.yaml" >/dev/null
kc rollout status deployment/spread -n "$NS" --timeout=180s >/dev/null
CP_PODS=$(kc get pods -n "$NS" -l app=spread --field-selector "spec.nodeName=$CLUSTER-control-plane" --no-headers | wc -l)
test "$CP_PODS" -eq 1
echo "OK 8 - the matching toleration reopens the control-plane node"

cleanup
if [ "$CREATED" -eq 1 ]; then
  CREATED=0
  if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
    echo "UNEXPECTED: dedicated cluster survived cleanup" >&2
    exit 1
  fi
else
  kc wait --for=delete namespace/"$NS" --timeout=120s >/dev/null
fi
echo "OK 9 - namespace, labels, and any newly created dedicated cluster were removed"

echo
echo "ALL CHECKS PASSED"
