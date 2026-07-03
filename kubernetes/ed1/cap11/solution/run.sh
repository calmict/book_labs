#!/usr/bin/env bash
set -euo pipefail

# Chapter 11 solution — steer the scheduler, then bypass it entirely.
# Requires kind and Docker; creates the book-labs-sched cluster (a control
# plane and two workers), or reuses it if already present.

CLUSTER=book-labs-sched
DIR=$(cd "$(dirname "$0")" && pwd)

KC() { kubectl --context "kind-$CLUSTER" "$@"; }

CREATED=0
PREV_CTX=$(kubectl config current-context 2>/dev/null || true)

cleanup() {
  if [ "$CREATED" -eq 1 ]; then
    kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
    if [ -n "$PREV_CTX" ] && [ "$PREV_CTX" != "kind-$CLUSTER" ]; then
      kubectl config use-context "$PREV_CTX" >/dev/null 2>&1 || true
    fi
  else
    KC delete pod witness bypass picky --ignore-not-found >/dev/null 2>&1 || true
    KC delete deployment spread --ignore-not-found >/dev/null 2>&1 || true
    KC label node "$CLUSTER-worker2" disk- >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "== 1. Reusing the existing $CLUSTER cluster =="
else
  echo "== 1. Creating the 3-node cluster (control plane + two workers) =="
  kind create cluster --config "$DIR/../start/kind-workers.yaml" --wait 180s
  CREATED=1
fi
KC get nodes
# idempotent start: clear any leftovers from a previous run
KC delete pod witness bypass picky --ignore-not-found >/dev/null 2>&1 || true
KC delete deployment spread --ignore-not-found >/dev/null 2>&1 || true
KC label node "$CLUSTER-worker" disk- >/dev/null 2>&1 || true
KC label node "$CLUSTER-worker2" disk- >/dev/null 2>&1 || true

echo
echo "== 2. The scheduler at work: the signature =="
KC run witness --image=alpine:3 -- sleep infinity
KC wait --for=condition=Ready pod/witness --timeout=180s >/dev/null
KC get pod witness -o wide
KC describe pod witness | grep ' Scheduled '

echo
echo "== 3. Bypassing the scheduler entirely =="
KC apply -f "$DIR/pod-bypass.yaml"
KC wait --for=condition=Ready pod/bypass --timeout=180s >/dev/null
KC get pod bypass -o wide
if KC describe pod bypass | grep -q ' Scheduled '; then
  echo "WARNING: a Scheduled event exists — the scheduler was consulted?!" >&2
else
  echo "(no Scheduled event at all: the scheduler never met this pod;"
  echo " the kubelet of the assigned node simply executed it)"
fi

echo
echo "== 4. Filtering: the picky pod =="
KC apply -f "$DIR/pod-picky.yaml"
sleep 5
KC get pod picky
KC describe pod picky | grep FailedScheduling | tail -1
echo "--- labelling one worker as the only worthy node ---"
KC label node "$CLUSTER-worker2" disk=ssd
KC wait --for=condition=Ready pod/picky --timeout=180s >/dev/null
KC get pod picky -o wide

echo
echo "== 5. Anti-affinity spreads, and the impossible third replica =="
KC apply -f "$DIR/deploy-spread.yaml"
KC rollout status deployment/spread --timeout=180s >/dev/null
KC get pods -l app=spread -o wide
KC scale deployment spread --replicas=3
sleep 5
KC get pods -l app=spread -o wide
PENDING=$(KC get pods -l app=spread --no-headers | grep -c Pending || true)
echo "pending replicas: $PENDING (two workers taken by the sisters — and"
echo "the control plane? see below)"

echo
echo "== 6. The taint, and the toleration that opens the door =="
KC describe node "$CLUSTER-control-plane" | grep -A1 Taints
KC apply -f "$DIR/deploy-spread-tolerated.yaml"
KC rollout status deployment/spread --timeout=180s >/dev/null
KC get pods -l app=spread -o wide
echo "(the third replica landed on the control plane: labels and affinity"
echo " attract, taints repel, and a toleration is the written permission)"
