# Chapter 10 — Write your controller in twenty lines

**Level:** Foundational

After LIST and WATCH, build the loop that receives state, measures the gap, and acts.

## Objectives

- Recognise the leader-election heartbeat in Lease objects (10.4).
- Write an observe-diff-act controller and watch it repair and prune Pods (10.1).
- Connect polling, informers, caches, and the duel between copies (10.3-10.4).

## Prerequisites

- Chapters 7 and 9 completed and a cluster reachable with kubectl.
- Bash. kind exposes the Lease; other distributions may produce a reasoned SKIP.

## The scenario

Complete start/minictl.sh in cap10-lab. The desired state is two app=minictl Pods.

### Phase 1 — Observe (10.1 — TODO 1)

Count non-terminating Pods: this is the reality observed by the controller.

### Phase 2 — Repair the deficit (10.1 — TODO 2)

When the count is below two, create one labelled Pod in the lab namespace.

### Phase 3 — Prune the excess (10.1 — TODO 3)

When the count exceeds two, select a non-terminating Pod and delete it. Then run:

    bash kubernetes/ed1/cap10/solution/run.sh

## Definition of "done"

- You read the Lease renewal, or the distribution produced a reasoned SKIP.
- The controller repairs one deletion and prunes one excess Pod.
- run.sh prints OK 1..7, or a reasoned SKIP 1, and ALL CHECKS PASSED.

## How it is verified

- OK 1 reads two renewTime values; OK 2 checks initial convergence.
- OK 3 and OK 4 check repair and pruning.
- OK 5 is the gate: with the controller stopped, the Pod does not return.
- OK 6 shows two unelected copies on the same state; OK 7 checks cleanup.

## Reflection questions

**a.** Where are observe, diff, and act, and how do they map to chapter 7's ReplicaSet controller?

**b.** Why does polling fail to scale, and what do informers and caches change?

**c.** Why can two copies duel, and how does a Lease select the leader and its successor?

## Cleanup

The check stops the controllers and deletes cap10-lab. On the manual path, stop the scripts with
Ctrl-C and delete the same namespace.

## Where it leads

You built the loop. Chapter 11 opens the controller that assigns each Pod to a node.
