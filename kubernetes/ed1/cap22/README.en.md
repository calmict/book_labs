# Chapter 22 — The Vault and the Corridor

**Level:** Advanced

RBAC closed the API boundary; now you close the paths between workloads with a network contract.

## Objectives

- Observe default allow and invert it with a default deny (22.1, 22.2).
- Allow only a labelled client on TCP 8080 (22.3).
- Deny egress and verify that the CNI enforces the policy (22.3, 22.4).

## Prerequisites

- Chapters 18 and 21 completed, kubectl available, and a reachable cluster.
- A CNI that supports NetworkPolicy. run.sh measures enforcement before trusting it.

## The scenario

Complete TODOs 1..3 in start/: the ingress default deny, the labelled exception, and the egress deny.
The test creates namespace vault and three Pods: safe, app, and guest.

    cd kubernetes/ed1/cap22/solution
    ./run.sh

### Phase 1 — The open corridor (22.1, 22.2)

Both clients reach the safe before any policy. The empty ingress permission set must then block both.

### Phase 2 — The nameplate door (22.3)

The additive exception admits role=app only on TCP 8080; the unlabelled guest remains outside.

### Phase 3 — No calls from the vault (22.3, 22.4)

The egress policy blocks a raw-IP call from safe and avoids confusing DNS with the tested path.

## Definition of "done"

- [ ] The three TODOs are complete.
- [ ] Default allow, ingress deny, labelled allow, and egress deny behave as described.
- [ ] run.sh prints OK 1..4 and ALL CHECKS PASSED.

## How it is verified

- OK 1 proves default allow with two successful requests.
- OK 2 is the first biting gate: the default deny blocks both clients and proves CNI enforcement.
- OK 3 proves the label-and-port exception while preserving the guest denial.
- OK 4 is the second biting gate: the safe cannot initiate the outgoing request.

## Reflection questions

**a.** Why is a flat network risky, what does an empty podSelector select, and why are policies additive?

**b.** Who may talk to whom, on which port, and how would relabelling guest change that contract?

**c.** Who turns NetworkPolicy objects into packet filtering, and why must DNS be considered for real egress policies?

## Cleanup

run.sh deletes namespace vault and every object in it, including on failure.

## Where this leads

The network boundary is closed. Chapter 23 narrows what each container can ask of the shared kernel.
