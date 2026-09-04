#!/usr/bin/env bash
# Chapter 8 completed commands. The verifier performs the same sequence with
# traps and assertions; these commands are the readable solution to the TODOs.
set -euo pipefail

CLUSTER=book-labs-ha
KC=(kubectl --context "kind-$CLUSTER")
ETCD_CERTS=(--cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key)

"${KC[@]}" create namespace raft-lab
"${KC[@]}" exec -n kube-system "etcd-$CLUSTER-control-plane" -- \
  etcdctl "${ETCD_CERTS[@]}" get /registry/namespaces/raft-lab --keys-only

STATUS=$("${KC[@]}" exec -n kube-system "etcd-$CLUSTER-control-plane" -- \
  etcdctl "${ETCD_CERTS[@]}" endpoint status --cluster -w table)
LEADER_IP=$(awk -F'|' '/ true / {gsub(/[[:space:]]/, "", $2); sub("https://", "", $2); sub(":2379", "", $2); print $2}' <<< "$STATUS")
LEADER_NODE=$("${KC[@]}" get nodes -o wide | awk -v ip="$LEADER_IP" '$6 == ip {print $1}')
mapfile -t SURVIVORS < <("${KC[@]}" get nodes -o name | sed 's|node/||' | grep -v "^$LEADER_NODE$")

docker pause "$LEADER_NODE" >/dev/null
sleep 5
"${KC[@]}" exec -n kube-system "etcd-${SURVIVORS[0]}" -- \
  etcdctl "${ETCD_CERTS[@]}" endpoint status --cluster -w table

docker pause "${SURVIVORS[1]}" >/dev/null
"${KC[@]}" get namespaces --request-timeout=5s || true
docker unpause "$LEADER_NODE" "${SURVIVORS[1]}" >/dev/null
