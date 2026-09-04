#!/usr/bin/env bash
# Chapter 8 verification - creates a dedicated three-control-plane kind cluster,
# reads etcd directly, forces a leader election, and proves quorum loss. It never
# operates on kind-book-labs and deletes only the dedicated cluster it creates.
set -euo pipefail

CLUSTER=book-labs-ha
HERE=$(cd "$(dirname "$0")" && pwd)
CONFIG="$HERE/../start/kind-ha.yaml"
PAUSED=()
CREATED=0
PREV_CTX=$(kubectl config current-context 2>/dev/null || true)

KC() { kubectl --context "kind-$CLUSTER" "$@"; }
etcd_exec() {
  local node=$1
  local output
  shift
  for _ in $(seq 1 12); do
    if output=$(KC exec -n kube-system "etcd-$node" -- etcdctl \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/server.crt \
      --key=/etc/kubernetes/pki/etcd/server.key "$@" 2>&1); then
      printf '%s\n' "$output"
      return 0
    fi
    sleep 2
  done
  printf '%s\n' "$output" >&2
  return 1
}
etcd_node_exec() {
  local node=$1
  local container
  shift
  container=$(docker exec "$node" crictl ps --name etcd -q)
  test -n "$container"
  docker exec "$node" crictl exec "$container" etcdctl \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key "$@"
}
cleanup() {
  if [ "${#PAUSED[@]}" -gt 0 ]; then
    docker unpause "${PAUSED[@]}" >/dev/null 2>&1 || true
    PAUSED=()
  fi
  if [ "$CREATED" -eq 1 ]; then
    kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
  else
    KC delete namespace raft-lab --ignore-not-found --wait=false >/dev/null 2>&1 || true
  fi
  if [ -n "$PREV_CTX" ] && kubectl config get-contexts -o name | grep -qx "$PREV_CTX"; then
    kubectl config use-context "$PREV_CTX" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "PRECHECK dedicated cluster already exists: it will be reused and preserved"
  # kind create writes the kubeconfig context itself; the reuse path must not
  # assume it is still there, or every later kubectl call fails with
  # "context was not found".
  kind export kubeconfig --name "$CLUSTER" >/dev/null 2>&1
else
  echo "PRECHECK creating the dedicated three-control-plane cluster"
  kind create cluster --config "$CONFIG" --wait 180s
  CREATED=1
fi

NODES=$(KC get nodes -o name)
test "$(wc -l <<< "$NODES")" -eq 3
STATUS=$(etcd_exec "$CLUSTER-control-plane" endpoint status --cluster -w table)
test "$(grep -c ' true ' <<< "$STATUS")" -eq 1
echo "OK 1 - three control-plane nodes expose three etcd members and one leader"

KC delete namespace raft-lab --ignore-not-found >/dev/null 2>&1 || true
KC create namespace raft-lab >/dev/null
KEY=$(etcd_exec "$CLUSTER-control-plane" get /registry/namespaces/raft-lab --keys-only)
grep -q '/registry/namespaces/raft-lab' <<< "$KEY"
echo "OK 2 - raft-lab exists literally as an etcd registry key"

LEADER_IP=$(awk -F'|' '/ true / {gsub(/[[:space:]]/, "", $2); sub("https://", "", $2); sub(":2379", "", $2); print $2}' <<< "$STATUS")
LEADER_NODE=$(KC get nodes -o wide | awk -v ip="$LEADER_IP" '$6 == ip {print $1}')
test -n "$LEADER_NODE"
mapfile -t SURVIVORS < <(KC get nodes -o name | sed 's|node/||' | grep -v "^$LEADER_NODE$")
test "${#SURVIVORS[@]}" -eq 2
docker pause "$LEADER_NODE" >/dev/null
PAUSED+=("$LEADER_NODE")
sleep 5
NEW_STATUS=$(for node in "${SURVIVORS[@]}"; do
  etcd_node_exec "$node" endpoint status -w table
done)
test "$(grep -c ' true ' <<< "$NEW_STATUS")" -eq 1
NEW_LEADER_IP=$(awk -F'|' '/ true / {gsub(/[[:space:]]/, "", $2); sub("https://", "", $2); sub(":2379", "", $2); print $2}' <<< "$NEW_STATUS")
test "$NEW_LEADER_IP" != "$LEADER_IP"
KC get namespaces --request-timeout=10s >/dev/null
echo "OK 3 - pausing the leader elects a different leader while the API stays available"

docker pause "${SURVIVORS[1]}" >/dev/null
PAUSED+=("${SURVIVORS[1]}")
sleep 5
if KC get namespaces --request-timeout=5s >/dev/null 2>&1; then
  echo "UNEXPECTED: the API answered after two of three etcd members were paused" >&2
  exit 1
fi
echo "OK 4 - the gate bites: one surviving member cannot serve a consistent read"

docker unpause "${PAUSED[@]}" >/dev/null
PAUSED=()
for _ in $(seq 1 60); do
  if KC get namespace raft-lab >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
KC get namespace raft-lab >/dev/null
RECOVERED=$(etcd_exec "$CLUSTER-control-plane" endpoint status --cluster -w table)
test "$(grep -c ' true ' <<< "$RECOVERED")" -eq 1
echo "OK 5 - quorum recovers and the replicated namespace remains present"

cleanup
if [ "$CREATED" -eq 1 ] && kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "UNEXPECTED: the dedicated cluster survived cleanup" >&2
  exit 1
fi
echo "OK 6 - paused nodes were resumed and created resources were removed"

echo
echo "ALL CHECKS PASSED"
