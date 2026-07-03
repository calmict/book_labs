#!/usr/bin/env bash
set -euo pipefail

# Chapter 10 solution — a hand-written controller: its self-healing, its
# trimming, and (as a show, not an assertion) the duel between two copies.
# Needs a reachable cluster (chapter 7's).

DIR=$(cd "$(dirname "$0")" && pwd)
CTRL="$DIR/minictl.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/lab-cap10.XXXXXX")
PIDS=""

cleanup() {
  if [ -n "$PIDS" ]; then
    # shellcheck disable=SC2086  # PIDS is a space-separated pid list
    kill $PIDS 2>/dev/null || true
  fi
  kubectl delete pods -l app=minictl --ignore-not-found --wait=false >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}
kubectl delete pods -l app=minictl --ignore-not-found >/dev/null

total() {
  kubectl get pods -l app=minictl --no-headers 2>/dev/null | grep -cv Terminating || true
}

wait_total() {
  local want=$1 waited=0
  until [ "$(total)" -eq "$want" ]; do
    sleep 2
    waited=$((waited + 2))
    if [ "$waited" -ge 120 ]; then
      echo "ERROR: timed out waiting for $want pods" >&2
      exit 1
    fi
  done
}

echo "== 1. The professionals' heartbeat =="
# on a freshly started cluster the lease may take a few seconds to appear;
# and some single-node distros (minikube) disable leader election entirely
waited=0
HAS_LEASE=1
until kubectl get lease kube-controller-manager -n kube-system >/dev/null 2>&1; do
  sleep 2
  waited=$((waited + 2))
  if [ "$waited" -ge 40 ]; then
    HAS_LEASE=0
    break
  fi
done
kubectl get leases -n kube-system
if [ "$HAS_LEASE" -eq 1 ]; then
  R1=$(kubectl get lease kube-controller-manager -n kube-system -o jsonpath='{.spec.renewTime}')
  sleep 4
  R2=$(kubectl get lease kube-controller-manager -n kube-system -o jsonpath='{.spec.renewTime}')
  echo "renewTime: $R1 -> $R2  (the leader proves it is alive)"
else
  echo "(no controller-manager lease here: single-node distros like minikube"
  echo " run with --leader-elect=false — use kind to see the heartbeat)"
fi

echo
echo "== 2-3. One controller at work: self-healing =="
bash "$CTRL" > "$TMP/ctrl1.log" 2>&1 &
PIDS=$!
wait_total 2
kubectl get pods -l app=minictl
VICTIM=$(kubectl get pods -l app=minictl -o jsonpath='{.items[0].metadata.name}')
echo "--- sabotage: deleting $VICTIM ---"
kubectl delete pod "$VICTIM" >/dev/null
wait_total 2
echo "--- healed, with no human intervention ---"
kubectl get pods -l app=minictl

echo
echo "== Trimming the excess =="
kubectl run minictl-extra --labels=app=minictl --image=alpine:3 -- sleep infinity >/dev/null
echo "(a third pod injected by hand)"
wait_total 2
echo "--- trimmed back to 2 ---"
kubectl get pods -l app=minictl

echo
echo "== 5. The duel: two copies of the same controller (a show) =="
# restart from scratch with TWO copies born in the same instant, so their
# observe ticks stay aligned and the race becomes visible
# shellcheck disable=SC2086  # PIDS is a space-separated pid list
kill $PIDS 2>/dev/null || true
PIDS=""
kubectl delete pods -l app=minictl --ignore-not-found >/dev/null 2>&1
: > "$TMP/ctrl1.log"
bash "$CTRL" > "$TMP/ctrl1.log" 2>&1 &
PIDS=$!
bash "$CTRL" > "$TMP/ctrl2.log" 2>&1 &
PIDS="$PIDS $!"
wait_total 2
VICTIM=$(kubectl get pods -l app=minictl -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$VICTIM" --wait=false >/dev/null
for t in 1 2 3 4 5 6 7 8 9 10 11 12; do
  echo "t=${t}s pods=$(total)"
  sleep 1
done
echo "--- what the two thermostats decided ---"
grep -h 'creating\|deleting' "$TMP/ctrl1.log" "$TMP/ctrl2.log" | tail -6
echo "(with two controllers the count can overshoot the desired 2 and"
echo " oscillate: that is exactly why the real ones elect a leader first)"
