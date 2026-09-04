# Chapter 7 — First contact: kill a Pod and watch who resurrects it

**Level:** Foundational

Containers now enter the cluster. In this lab you distinguish the brain from the arms and watch the
declarative model correct real sabotage.

## Objectives

- Recognise the control-plane components and the workers' role (7.1).
- Declare two replicas and observe the reconciliation loop (7.2).
- Read spec and status in the same API object (7.3).

## Prerequisites

- Part 1 completed and a reachable local cluster; see [SETUP.md](../../SETUP.md).
- kubectl configured; kubectl get nodes must answer.

## The scenario

Complete start/deployment.yaml, then apply it in the lab's isolated namespace.

    kubectl create namespace lab-cap07
    kubectl apply -f kubernetes/ed1/cap07/start/deployment.yaml

### Phase 1 — The desired state (7.2 — TODO 1)

Request two replicas: this number is the contract that the controller must maintain.

### Phase 2 — The arms (7.1 — TODO 2)

Select alpine:3 and use kubectl get pods -n lab-cap07 -o wide to see where the containers run. Use
kubectl get pods -n kube-system to recognise etcd, API server, scheduler, and controller manager.

### Phase 3 — Desire and reality (7.3 — TODO 3)

Keep the process alive, wait for two ready Pods, and compare spec.replicas with
status.readyReplicas. Delete one Pod and verify that another appears with a different name. Finally
query kubectl api-resources and kubectl explain deployment.spec.replicas. Run the check:

    bash kubernetes/ed1/cap07/solution/run.sh

## Definition of "done"

- You identified the four control-plane components.
- Spec and status converge on two replicas and the deleted Pod is replaced.
- run.sh prints OK 1..5 and ALL CHECKS PASSED.

## How it is verified

- OK 1 recognises the four components in the system namespace.
- OK 2 compares the desired state with ready replicas.
- OK 3 is the gate: the deleted Pod name must disappear and a replacement must appear.
- OK 4 queries the resources and documentation built into the API.
- OK 5 confirms removal of the lab namespace.

## Reflection questions

**a.** What is each control-plane component's role, and why is the kubelet not a Pod?

**b.** What does the controller compare after deletion, and who materially creates the new Pod?

**c.** Who writes spec and who writes status? Why does this separation make the model declarative?

## Cleanup

The check deletes lab-cap07 and all its objects. For the manual path:

    kubectl delete namespace lab-cap07

## Where it leads

You saw the desired state survive sabotage. Chapter 8 descends into the distributed memory that
stores that desire.
