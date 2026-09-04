#!/usr/bin/env bash
# Chapter 8 start - inspect etcd, pause its leader, and observe quorum loss.
# Valid but incomplete. Run only against the dedicated book-labs-ha cluster.
set -euo pipefail

CLUSTER=book-labs-ha
KC=(kubectl --context "kind-$CLUSTER")

# TODO 1 (8.1): create raft-lab and query its /registry/namespaces key with
# etcdctl. This connects a Kubernetes object to the underlying key-value store.
:

# TODO 2 (8.2): identify the current leader, pause that kind node, and query a
# survivor. Pausing preserves the member IP while forcing a real Raft election.
:

# TODO 3 (8.3): pause one more member, require a timed API read to fail, then
# unpause both nodes. This demonstrates majority loss and recovery.
:
