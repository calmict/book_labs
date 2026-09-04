# Chapter 26 — The Ledger and the Auditor

**Level:** Cloud Architect

You have learned to observe the cluster; now you hand ArgoCD a ledger and ask it to correct every divergence.

## Objectives

- Use Git as the single source of declarative truth (26.1).
- Define the source, destination, and policy of an ArgoCD Application (26.2).
- Observe sync, drift, self-heal, and rollback with git revert (26.3, 26.4).

## Prerequisites

- kind, Docker, and kubectl available; at least 3 GB free in Docker storage.
- Internet access to download the ArgoCD manifest and images.
- Chapters 15, 24, and 25 completed.

## The scenario

An internal Git server hosts a one-replica Deployment. Complete TODOs 1..3 in the Application; ArgoCD must build the world from the ledger, erase drift, and propagate a revert.

    cd kubernetes/ed1/cap26/solution
    ./run.sh

### Phase 1 — Assign the ledger to the auditor (26.1, 26.2)

Define the repository, revision, path, and destination namespace.

### Phase 2 — Introduce drift (26.3)

Scale the Deployment by hand: selfHeal must detect the divergence and restore one replica.

### Phase 3 — Correct the ledger (26.4)

One commit raises replicas to five; git revert returns desired state to one and ArgoCD propagates it.

## Definition of "done"

- [ ] The three TODOs are complete and the Application is Synced and Healthy.
- [ ] Manual drift is undone.
- [ ] The commit and revert produce five and then one replica.
- [ ] run.sh prints OK 1..4 — or a reasoned SKIP 1 — and ALL CHECKS PASSED.

## How it is verified

- OK 1 verifies the dedicated cluster, ArgoCD, and the Git ledger.
- OK 2 verifies the first sync and Healthy state.
- OK 3 is the biting gate: three replicas really exist before selfHeal restores one.
- OK 4 verifies that the commit and revert govern live state.

## Reflection questions

**a.** Why is Git the source of truth, and what advantages does ArgoCD's pull model have over pipeline push?

**b.** What do Synced, OutOfSync, and Healthy mean, and why is reconciliation continuous?

**c.** Why does GitOps rollback use git revert, and how does that differ from helm rollback?

## Cleanup

run.sh always deletes the dedicated book-labs-gitops cluster and restores the previous kubectl context.

## Where this leads

GitOps governs declared state. The next chapter moves security and routing out of applications with a service mesh.
