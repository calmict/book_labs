# Chapter 13 — The Investigation: Who Touched My Pod?

> Exercise for **Chapter 13 — The Life of a Pod: From kubectl apply to the Running Container** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- reconstruct the whole relay race of a kubectl apply from the evidence: four different signatures on the events (deployment-controller, replicaset-controller, default-scheduler, kubelet);
- follow the chain of ownership Deployment → ReplicaSet → Pod written in the ownerReferences, and descend below the API down to the Linux process — meeting the namespaces and cgroups of Phases 1-2 again;
- tell the two cures apart: the kubelet restarting a dead container (same Pod, RESTARTS climbing) and the controller replacing a deleted Pod (new name).

## Prerequisites

- Phases 1 and 2 completed (chapters 1-12): this chapter is their recap exam.
- The book-labs cluster running; node access via docker exec (kind, or minikube on the Docker driver).
- The starting manifest start/relay.yaml has TODOs to complete (from this chapter on the level rises: more YAML written by you).

## Instructions

1. Turn on the black box. In one terminal, record everything that happens:

       kubectl get events -w

2. The fact. Complete start/relay.yaml (a Deployment, 1 replica, label app=relay, a container named relay with alpine:3 and sleep infinity: the TODOs guide you) and from a second terminal set off the relay:

       kubectl apply -f relay.yaml

   In the first terminal, within a couple of seconds, it is all over. Stop the watch: now we investigate cold.

3. The four signatures. Collect the evidence with the investigation form (an events view that shows who signed what):

       kubectl get events --sort-by=.metadata.creationTimestamp -o custom-columns='TIME:.metadata.creationTimestamp,SIGNATURE:.source.component,REASON:.reason,OBJECT:.involvedObject.name' | grep relay

   Recognise the signatories: ScalingReplicaSet (deployment-controller), SuccessfulCreate (replicaset-controller), Scheduled (default-scheduler), Pulled/Created/Started (kubelet). Four different hands, no central director. Beware: timestamps have one-second precision, so events born in the same instant may appear shuffled — the logical order is yours to reconstruct (who can have created what?), and that is part of the investigation.

4. The chain of ownership. Three objects were born from a single apply:

       kubectl get deployment,replicaset,pod -l app=relay
       kubectl get pod -l app=relay -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}{" -> "}{.items[0].metadata.ownerReferences[0].name}{"\n"}'
       kubectl get rs -l app=relay -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}{" -> "}{.items[0].metadata.ownerReferences[0].name}{"\n"}'

   The Pod belongs to the ReplicaSet, which belongs to the Deployment: the relay race is also a chain of delegation written in the metadata.

5. Below the API, down to the process. Enter the node and meet the foundations again:

       NODE=$(kubectl get pods -l app=relay -o jsonpath='{.items[0].spec.nodeName}')
       CID=$(docker exec $NODE crictl ps --name relay -q)
       PID=$(docker exec $NODE crictl inspect -o go-template --template '{{.info.pid}}' $CID)
       docker exec $NODE cat /proc/$PID/cgroup
       docker exec $NODE readlink /proc/$PID/ns/pid

   There it is: a Linux process, in its kubepods cgroup (chapter 3 — and in the path you can also read the QoS class, besteffort) and in its namespaces (chapter 2), started by the runtime chain (chapter 5) on the kubelet's order (chapter 12), on a node chosen by the scheduler (chapter 11), by the will of two controllers (chapter 10), everything persisted in etcd (chapter 8) through the apiserver (chapter 9). One apply, thirteen chapters.

6. The two cures (§13.4). First kill the PROCESS, behind the API's back:

       docker exec $NODE kill -9 $PID
       kubectl get pods -l app=relay

   Same Pod, RESTARTS up to 1: the kubelet noticed (chapter 12's PLEG) and restarted the container. Now delete the POD instead:

       kubectl delete pod <the-pod-name>
       kubectl get pods -l app=relay

   New name: this time the ReplicaSet controller acted (chapters 7 and 10). Two different doctors for two different deaths — note how you can tell them apart from the outside.

7. The questions for answers.md, then tear down:

       kubectl delete deployment relay

   The questions: (a) the relay timeline with the four signatures and the map signatory → chapter (plus the logical order reconstructed beyond the timestamps); (b) the two cures of step 6: who acted in each case, which signal gives it away (RESTARTS climbing vs the name changing), and why are both levels of healing needed? (c) ownerReferences: what are they for, and what do you expect to happen if you delete the ReplicaSet instead of the Pod? (think about the cascade, and about the Deployment noticing)

## Definition of "done"

- [ ] You have the timeline with the four signatures and the reconstructed logical order.
- [ ] You have the chain Pod → ReplicaSet → Deployment read from the ownerReferences.
- [ ] You found the PID on the node and its kubepods cgroup with the QoS class in the path.
- [ ] You observed both cures: RESTARTS at 1 after the kill -9, a new name after the delete.
- [ ] answers.md answers the three questions and the Deployment has been removed.
