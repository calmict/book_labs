#!/usr/bin/env bash
set -euo pipefail

# Chapter 8 solution — kill the etcd leader, break the quorum, resurrect.
# Requires kind and Docker (the nodes are containers: that is our weapon).
# Creates the 3-control-plane cluster book-labs-ha, or reuses it if present;
# it deletes it at the end only if this script created it.

CLUSTER=book-labs-ha
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG="$SCRIPT_DIR/../start/kind-ha.yaml"

KC() { kubectl --context "kind-$CLUSTER" "$@"; }

# etcdctl inside an etcd pod, with the cluster certificates
etcd_exec() {
  local pod=$1
  shift
  KC exec -n kube-system "etcd-$pod" -- etcdctl \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key "$@"
}

CREATED=0
PAUSED=""
PREV_CTX=$(kubectl config current-context 2>/dev/null || true)

cleanup() {
  if [ -n "$PAUSED" ]; then
    # shellcheck disable=SC2086  # PAUSED is a space-separated node list
    docker unpause $PAUSED >/dev/null 2>&1 || true
  fi
  if [ "$CREATED" -eq 1 ]; then
    kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
    if [ -n "$PREV_CTX" ] && [ "$PREV_CTX" != "kind-$CLUSTER" ]; then
      kubectl config use-context "$PREV_CTX" >/dev/null 2>&1 || true
    fi
  else
    KC delete namespace raft-lab --ignore-not-found >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "== 1. Reusing the existing $CLUSTER cluster =="
else
  echo "== 1. Creating the 3-control-plane cluster (this takes a few minutes) =="
  kind create cluster --config "$CONFIG" --wait 180s
  CREATED=1
fi
KC get nodes

echo
echo "== 2. Three etcd members, one leader =="
STATUS=$(etcd_exec "$CLUSTER-control-plane" endpoint status --cluster -w table)
echo "$STATUS"
LEADER_IP=$(echo "$STATUS" | grep ' true ' | awk -F'|' '{print $2}' | tr -d ' ' | sed 's|https://||;s|:2379||')
LEADER_NODE=$(KC get nodes -o wide | awk -v ip="$LEADER_IP" '$6 == ip {print $1}')
echo "leader: $LEADER_NODE ($LEADER_IP)"

echo
echo "== 3. A Kubernetes object is a key in etcd =="
KC create namespace raft-lab
etcd_exec "$CLUSTER-control-plane" get /registry/namespaces/raft-lab --keys-only

echo
echo "== 4. The murder: freeze the leader's node (it is just a container) =="
# pause, not stop: a restart could reshuffle the node IPs, and etcd member
# identities are tied to them
docker pause "$LEADER_NODE" >/dev/null
PAUSED="$LEADER_NODE"
echo "paused: $LEADER_NODE"
# pick a surviving control-plane node to interrogate
SURVIVOR=""
SECOND=""
for n in "$CLUSTER-control-plane" "$CLUSTER-control-plane2" "$CLUSTER-control-plane3"; do
  if [ "$n" != "$LEADER_NODE" ]; then
    if [ -z "$SURVIVOR" ]; then SURVIVOR=$n; else SECOND=$n; fi
  fi
done
sleep 5
echo "--- the election has already happened (asked to $SURVIVOR) ---"
etcd_exec "$SURVIVOR" endpoint status --cluster -w table 2>&1 || true
echo "--- and the cluster still answers: 2 out of 3 is a majority ---"
KC get nodes

echo
echo "== 5. Breaking the quorum: freeze a second member =="
docker pause "$SECOND" >/dev/null
PAUSED="$PAUSED $SECOND"
echo "paused: $SECOND"
sleep 5
set +e
KC get namespaces --request-timeout=5s
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  echo "(frozen as expected: 1 member out of 3 is not a majority — no reads,"
  echo " no writes, until the quorum is back)"
else
  echo "WARNING: the apiserver still answered — quorum not broken as expected" >&2
fi

echo
echo "== 6. The resurrection =="
# shellcheck disable=SC2086  # PAUSED is a space-separated node list
docker unpause $PAUSED >/dev/null
PAUSED=""
echo -n "waiting for the cluster to thaw"
for _ in $(seq 1 60); do
  if KC get namespaces >/dev/null 2>&1; then break; fi
  echo -n "."
  sleep 5
done
echo
KC get namespaces | grep raft-lab
etcd_exec "$CLUSTER-control-plane" endpoint status --cluster -w table
echo "(three members, one leader, and raft-lab never lost: it was replicated)"
