# Chapter 20 — The Arranged Marriage

**Level:** Cloud Architect

After routing requests, you assign storage without tying the application to a particular disk: the
PVC asks, the PV offers, and the binder arranges the marriage.

## Objectives

- Bind a PVC to a compatible static PV and observe the one-to-one constraint (20.1).
- Trigger dynamic provisioning through the default StorageClass (20.2).
- Compare the Retain and Delete reclaim policies in operation (20.3).
- Recognize the provisioner as a controller and connect it to the CSI interface (20.4).

## Prerequisites

- A kind cluster, or minikube with the Docker driver, and a node reachable through docker exec.
- A working default StorageClass.
- Chapters 10 and 16 completed for reconciliation loops and StatefulSet storage.

## The scenario

Complete TODOs 1..3 in start/: the static request, the dynamic request, and the policy that preserves
data. The test works in namespace lab-cap20 and uses a node hostPath only to make the static PV's data
survival directly observable.

    cd kubernetes/ed1/cap20/solution
    ./run.sh

### Phase 1 — The static marriage (20.1)

bride requests 30Mi from the manual class and binds to the compatible 50Mi PV. spinster makes the same
request after the only PV is occupied and stays Pending: binding is exclusive.

### Phase 2 — The automatic matchmaker (20.2, 20.4)

cloud names no class: the default class observes the PVC and creates a new PV when tenant consumes it.

### Phase 3 — Two different separations (20.3)

When the claims are deleted, Delete removes the dynamic volume; Retain leaves manual-pv Released and
preserves the file written by the Pod.

## Definition of "done"

- [ ] The three TODOs are complete and the manifests describe both provisioning forms.
- [ ] spinster remains Pending while bride occupies the static PV.
- [ ] run.sh prints OK 1..6 and ALL CHECKS PASSED.

## How it is verified

- OK 1 verifies compatible static binding.
- OK 2 is the biting gate: the second claim stays Pending without another PV.
- OK 3 verifies the PV created by the default StorageClass.
- OK 4 compares the Delete and Retain policies.
- OK 5 verifies that the dynamic PV disappears.
- OK 6 verifies the static PV's Released state and preserved data.

## Reflection questions

**a.** Which criteria does the binder use, why is the bond one-to-one, and what is spinster waiting for?

**b.** When is Retain appropriate, what is Delete's risk, and how can a Released PV be made reusable?

**c.** Why are CSI, CRI, and CNI interfaces? Where does the controller pattern appear in provisioning?

## Cleanup

run.sh deletes namespace lab-cap20, both PVs, and the hostPath directory created inside the node. It
does not alter the StorageClass or cluster configuration.

## Where this leads

You separated request from implementation in storage. Chapter 21 applies the same idea to identity and
permissions: authenticating someone does not yet authorize them.
