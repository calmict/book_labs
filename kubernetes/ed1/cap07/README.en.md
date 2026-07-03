# Chapter 7 — First Contact: Kill a Pod and Watch Who Resurrects It

> Exercise for **Chapter 7 — The Architecture at a Glance** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- start a local cluster and recognise at a glance the control plane components (the brain) and what runs on the workers (the arms);
- experience the declarative model firsthand: you declare the desired state, the reconciliation loop chases it — even against your sabotage;
- read a Kubernetes object the way the API sees it: spec (desired) versus status (observed), and discover that everything really is a resource.

## Prerequisites

- Phase 1 completed (chapters 1-6): from here on, containers are a given.
- A local cluster: follow [SETUP.md](../../SETUP.md) (kind recommended; minikube or k3d work too).
- kubectl configured (kubectl get nodes must answer).

## Instructions

1. Start the cluster (once: the next chapters will reuse it) and introduce yourself:

       kind create cluster --name book-labs
       kubectl get nodes -o wide

2. The building tour: look at who lives in the system namespace and recognise the brain:

       kubectl get pods -n kube-system

   Identify and note down: kube-apiserver (the switchboard), etcd (the memory), kube-scheduler (who decides where), kube-controller-manager (who chases the desired state), plus kube-proxy and the CNI. Curious detail: the kubelet is NOT in the list — it runs as a process on the node, outside the cluster it watches over (with kind: docker exec book-labs-control-plane pgrep -l kubelet — chapter 5 comes in handy).

3. Declare a desired state: two replicas of a sleeping process (your old friends from Phase 1):

       kubectl create deployment lab-cap07 --replicas=2 --image=alpine:3 -- sleep infinity
       kubectl get pods -o wide

   Wait until both Pods are Running and note their names and node.

4. The sabotage: kill a Pod and watch the loop at work. In one terminal leave this running:

       kubectl get pods -w

   and from a second terminal:

       kubectl delete pod <one-of-the-two-pods>

   Watch the sequence in the first terminal: the Pod dies, and a new one is born right away with a different name. You changed the observed state, not the desired one: the controller saw the difference and corrected it. Close the watch with Ctrl-C.

5. Look at the written contract: desired and observed state live in the same object:

       kubectl get deployment lab-cap07 -o yaml

   Find the spec section (replicas: 2 — your wish) and the status section (readyReplicas — reality). All of Kubernetes is this comparison, repeated forever.

6. Everything is a resource: ask for the full list and query the built-in documentation:

       kubectl api-resources | head -15
       kubectl explain deployment.spec.replicas

   Nodes, namespaces, events too: everything can be read with kubectl get. Try: kubectl get events --sort-by=.metadata.creationTimestamp | tail -5 — can you recognise the events of your sabotage?

   The three questions for answers.md: (a) list the control plane components seen in step 2 with each one's role in a single sentence; why is the kubelet not among the Pods? (b) tell the story of step 4 from the controller's point of view: what did it compare, what did it decide, who materially created the new Pod? (c) in the YAML of step 5, who writes the spec and who writes the status? Why is this separation the heart of the declarative model?

7. Clean up (you can leave the cluster running: the next chapters reuse it):

       kubectl delete deployment lab-cap07

   If you want to switch everything off instead: kind delete cluster --name book-labs.

## Definition of "done"

- [ ] kubectl get nodes answers and you identified the 4 brain components in kube-system.
- [ ] In the watch you saw the deleted Pod and its replacement being born with another name, with no intervention of yours.
- [ ] You can point at where the wish lives (spec) and where reality lives (status) in the Deployment YAML.
- [ ] answers.md answers the three questions.
- [ ] The lab Deployment has been removed.
