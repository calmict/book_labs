# Chapter 23 — The Cardboard King

**Level:** Cloud Architect

The network boundary is closed; now you reduce what a process may do through the kernel shared with its host.

## Objectives

- Inspect uid, capabilities, seccomp mode, and filesystem writability (23.1, 23.2).
- Apply a restricted SecurityContext and verify each defence (23.2, 23.3).
- Enforce Pod Security Standards across a namespace (23.5).

## Prerequisites

- kubectl available and a reachable cluster with Pod Security admission enabled.
- Chapters 4 and 22 completed for capabilities, the shared kernel, and policy enforcement.

## The scenario

Complete TODOs 1..3 in start/hardened.yaml: non-root identity, reduced privileges and writable surface,
and RuntimeDefault seccomp. run.sh creates namespace throne and compares the hardened Pod with king.

    cd kubernetes/ed1/cap23/solution
    ./run.sh

### Phase 1 — The naked king (23.1, 23.2)

Inspect the default container and prove that it is uid 0, retains capabilities, has no seccomp filter,
and can write its root filesystem.

### Phase 2 — Stripping the crown (23.2, 23.3)

Apply the completed SecurityContext and verify non-root execution, zero effective capabilities,
seccomp filter mode, and a read-only root filesystem.

### Phase 3 — The namespace guard (23.5)

Enable restricted enforcement, observe that admission is not retroactive, reject a new plain Pod,
and admit the hardened Pod.

## Definition of "done"

- [ ] The three TODOs are complete.
- [ ] Every process-level defence is observed in the running Pod.
- [ ] run.sh prints OK 1..5 and ALL CHECKS PASSED.

## How it is verified

- OK 1 establishes the insecure baseline.
- OK 2 verifies all five SecurityContext effects.
- OK 3 proves that admission does not evict an existing Pod.
- OK 4 is the biting gate: restricted admission refuses the uncorrected Pod.
- OK 5 proves that the corrected Pod passes the same gate.

## Reflection questions

**a.** Why is container root dangerous on a shared kernel, and what boundary does each SecurityContext setting add?

**b.** How does seccomp differ from AppArmor or SELinux, and what does RuntimeDefault provide?

**c.** How do the Pod Security levels and modes differ, and why should warn or audit precede enforce?

## Cleanup

run.sh deletes namespace throne and all Pods in it, including on failure.

## Where this leads

You can now protect workloads individually and at admission time. Chapter 24 packages coordinated objects as releases.
