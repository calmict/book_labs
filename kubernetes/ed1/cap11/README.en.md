# Chapter 11 — Steer the scheduler, then bypass it

**Level:** Foundational

The loop now has one precise job: choose the node, without executing the Pod.

## Objectives

- Separate the scheduler's decision from kubelet execution (11.1).
- See filtering and scoring through a Pending Pod and its events (11.2).
- Steer placement with nodeSelector, anti-affinity, taints, and tolerations (11.3-11.4).

## Prerequisites

- kind, Docker, and kubectl. The check creates the dedicated three-node book-labs-sched cluster.
- It neither uses nor modifies book-labs-control-plane.

## The scenario

Work in cap11-lab on the dedicated cluster. Complete the three manifests in start/.

### Phase 1 — Bypass the scheduler (11.1 — TODO 1)

Assign nodeName to bypass: it gets no Scheduled event, but the kubelet still executes it.

### Phase 2 — Build the filter (11.2-11.3 — TODO 2)

Require disk=ssd with nodeSelector. At first no node passes; then a label opens the path.

### Phase 3 — Separate the replicas (11.3 — TODO 3)

Add strict anti-affinity. Replica three stays Pending until a toleration opens the tainted
control-plane node. Run:

    bash kubernetes/ed1/cap11/solution/run.sh

## Definition of "done"

- You compared a scheduled Pod with one assigned directly.
- You observed both Pending states and their FailedScheduling reasons.
- run.sh prints OK 1..9 and ALL CHECKS PASSED.

## How it is verified

- OK 1 checks topology; OK 2 and OK 3 distinguish selection from bypass.
- OK 4 is the selector gate; OK 5 checks the label that reopens it.
- OK 6 checks spreading; OK 7 is the anti-affinity plus taint gate.
- OK 8 checks the toleration; OK 9 checks complete cleanup.

## Reflection questions

**a.** What does the scheduler actually do, and who executes the bypass Pod?

**b.** What kept picky Pending, what unblocked it, and when does scoring run?

**c.** In which opposite directions do affinity and taints act, and what does a toleration grant?

## Cleanup

If the check creates book-labs-sched, it deletes it. If that cluster already exists, it removes
cap11-lab and the lab labels while leaving the cluster running.

## Where it leads

You separated decision from execution. Chapter 12 boards the node and observes the kubelet.
