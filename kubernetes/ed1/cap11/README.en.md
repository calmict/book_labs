# Chapter 11 — Steer the Scheduler (Then Bypass It)

> Exercise for **Chapter 11 — The Scheduler** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- demonstrate what the scheduler actually does (it chooses and writes the node) and what it does not — to the point of bypassing it entirely with a Pod that never meets it;
- see filtering in action: a Pod rejected by every node stays Pending, with the reason written in its events;
- steer the choices with nodeSelector and anti-affinity, and understand taints as repulsion (with the toleration reopening the door).

## Prerequisites

- Chapters 7-10 completed.
- kind and Docker: a dedicated cluster with 2 workers is needed (start/kind-workers.yaml provided); as with chapter 8, mind the inotify limits (Troubleshooting in [SETUP.md](../../SETUP.md)).
- The starting manifests in start/ have TODOs to complete.

## Instructions

1. Create the 3-node cluster and look at the geography:

       kind create cluster --config start/kind-workers.yaml
       kubectl get nodes

   One control plane and two workers. First question to keep in mind: why will no Pod ever land on the control plane in the next steps?

2. The scheduler at work. Create any Pod and look for the artist's signature:

       kubectl run witness --image=alpine:3 -- sleep infinity
       kubectl get pod witness -o wide
       kubectl describe pod witness

   Among the events there is the Scheduled line signed by default-scheduler: it picked a worker (filtering + scoring) and wrote down its decision. Note the node.

3. Now bypass it. Complete start/pod-bypass.yaml: there is a TODO where you set spec.nodeName directly (pick either worker). Then:

       kubectl apply -f pod-bypass.yaml
       kubectl describe pod bypass

   The Pod runs, but there is NO Scheduled line in its events: by assigning the node yourself, the scheduler was never consulted — the kubelet of that node saw an assigned Pod and executed it. That is what the scheduler does not do: execute. It only decides.

4. Filtering that rejects. Complete start/pod-picky.yaml: the TODO is a nodeSelector with disk: ssd. Apply and observe:

       kubectl apply -f pod-picky.yaml
       kubectl get pod picky
       kubectl describe pod picky

   Pending, with the reason in black and white: no node survives the filter (0/3 nodes available... didn't match). Now create the only worthy node by labelling it:

       kubectl label node <a-worker> disk=ssd
       kubectl get pod picky -o wide

   Unblocked, and precisely on the labelled node. Filtering is no magic: it is a sieve.

5. Anti-affinity spreads. Complete start/deploy-spread.yaml: the TODO is the podAntiAffinity block (required, topologyKey kubernetes.io/hostname) on a 2-replica Deployment. Apply and verify:

       kubectl apply -f deploy-spread.yaml
       kubectl get pods -l app=spread -o wide

   One replica per worker. Now ask the impossible:

       kubectl scale deployment spread --replicas=3
       kubectl get pods -l app=spread -o wide

   The third stays Pending: the two workers are taken by its sisters, and the third node... why does it not go to the control plane?

6. The taint: repelling instead of attracting. Look at what protects the control plane:

       kubectl describe node book-labs-sched-control-plane | grep -A2 Taints

   There it is: node-role.kubernetes.io/control-plane:NoSchedule. Labels and affinities attract; a taint repels anyone without written permission. Grant that permission to the third replica: add to the Deployment template the toleration for that taint (key, operator Exists, effect NoSchedule), set replicas to 3 in the manifest and re-apply. The third replica now lands right on the control plane.

   The three questions for answers.md: (a) what does the scheduler actually do, and what did you prove with the bypass Pod? Who executed that Pod, if the scheduler never saw it? (b) tell the journey of the picky Pod: what kept it Pending, what unblocked it, and where do filtering and scoring act? (c) explain the opposite directions of affinity and taints (attract vs repel) using the third replica as evidence: what was it missing before the toleration?

7. Tear down the lab (the dedicated cluster only):

       kind delete cluster --name book-labs-sched

## Definition of "done"

- [ ] You have the Scheduled event signed by default-scheduler for witness, and its absence for bypass.
- [ ] You saw picky Pending with the filter's reason, then Running on the labelled node.
- [ ] The 2 spread replicas sit on different workers, and the third went from Pending to the control plane thanks to the toleration.
- [ ] answers.md answers the three questions.
- [ ] The book-labs-sched cluster has been deleted.
