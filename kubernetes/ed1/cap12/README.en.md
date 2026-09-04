# Chapter 12 — The ship's doctor: probes, restarts, and resurrection

**Level:** Foundational

After the scheduler's choice, observe the kubelet keeping the Pod healthy and ready on its node.

## Objectives

- Watch failed liveness restart the container and produce back-off (12.2).
- Watch readiness remove and restore traffic without a restart (12.2).
- Create a static Pod and prove its resurrection by the kubelet (12.1).

## Prerequisites

- Chapters 7-11 completed and the kind cluster reachable with kubectl.
- Docker must be able to execute commands in the kind node. The check never stops or restarts it.

## The scenario

Work in cap12-lab. Complete both probes and isolate the static Pod in that namespace.

### Phase 1 — The process that lies (12.2 — TODO 1)

Add the exec liveness probe. The process remains alive after removing its file; the kubelet
restarts it and the persistent marker makes later attempts fail, exposing their back-off.

### Phase 2 — The benched patient (12.2 — TODO 2)

Add the exec readiness probe. Removing the file takes the Pod out of the endpoints without a
restart; restoring the file returns it to traffic.

### Phase 3 — The autonomous kubelet (12.1 — TODO 3)

Assign cap12-lab to the static Pod and place its manifest in the directory watched by the kubelet.
Deleting the API mirror is insufficient: only removing the file stops it. Run:

    bash kubernetes/ed1/cap12/solution/run.sh

## Definition of "done"

- You distinguished a liveness restart from readiness traffic removal.
- You saw the static Pod return with a new UID.
- run.sh prints OK 1..9 and ALL CHECKS PASSED.

## How it is verified

- OK 1 is the no-liveness gate; OK 2 checks restarts, events, and growing intervals.
- OK 3-5 check the healthy endpoint, removal without restart, and recovery.
- OK 6 creates the static Pod; OK 7 is the resurrection gate.
- OK 8 checks that the file is the source of truth; OK 9 checks cleanup.

## Reflection questions

**a.** Why is a bad liveness probe more dangerous than a bad readiness probe?

**b.** Who resurrects the static Pod, and how does that differ from chapter 7's ReplicaSet?

**c.** Why is kubelet eviction related to chapter 3's OOM kill?

## Cleanup

The check removes the node manifest and deletes cap12-lab. On the manual path, remove the file
from the node first, wait for the mirror to vanish, and then delete the namespace.

## Where it leads

The journey from an API request to a healthy container is complete. Chapter 13 reassembles it
through Pods and their lifecycle.
