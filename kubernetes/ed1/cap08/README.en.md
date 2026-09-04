# Chapter 8 — Kill the leader: quorum and elections in etcd

**Level:** Foundational

Chapter 7's desired state must survive failures. Here you find it as a replicated key and measure
the difference between losing a leader and losing the majority.

## Objectives

- Query three etcd members and find an object as a key (8.1).
- Force a Raft election without changing member addresses (8.2).
- Lose and restore quorum in a three-member cluster (8.3-8.4).

## Prerequisites

- Chapter 7 completed, kind, Docker, and kubectl.
- About 4 GB of free RAM.
- The check creates only the dedicated book-labs-ha cluster and deletes it afterward. It never
  reuses or changes kind-book-labs.

## The scenario

start/kind-ha.yaml describes three control planes. Complete start/raft-lab.sh and, for the manual
path, create the dedicated cluster:

    kind create cluster --config kubernetes/ed1/cap08/start/kind-ha.yaml

### Phase 1 — Memory as keys (8.1 — TODO 1)

Create raft-lab and use etcdctl inside an etcd Pod to find /registry/namespaces/raft-lab.

### Phase 2 — The election (8.2 — TODO 2)

Identify the sole leader, map its IP to the kind node, and pause that node. Query a survivor: a
different leader must emerge while the API continues to answer.

### Phase 3 — The quorum (8.3 — TODO 3)

Pause a second member and request a consistent read with a timeout: one member cannot form a
majority. Restore both and verify that raft-lab remains. Run:

    bash kubernetes/ed1/cap08/solution/run.sh

## Definition of "done"

- You saw three members, one leader, and the namespace key.
- After the first pause the API answers with a new leader; after the second it cannot read.
- run.sh prints OK 1..6 and ALL CHECKS PASSED.

## How it is verified

- OK 1 checks three nodes and one leader; OK 2 finds the key in etcd.
- OK 3 proves election and availability with two members.
- OK 4 is the gate: with one member, the consistent read must fail.
- OK 5 proves recovery and persistence; OK 6 checks node resumption and cleanup.

## Reflection questions

**a.** What is the majority rule, and why do two members tolerate no more failures than one?

**b.** Who elects the new leader, and why does Kubernetes continue to answer?

**c.** Why can existing containers continue while the control plane is frozen?

## Cleanup

The check always resumes paused nodes. If it created book-labs-ha, it deletes it; if the cluster
already existed, it preserves it and removes only raft-lab.

## Where it leads

You observed the cluster's consistent memory. Chapter 9 follows requests through the only component
allowed to read and change it: the API server.
