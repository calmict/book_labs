# Chapter 7 — Answers (model solution)

## The brain, component by component

    etcd-...                      <- the memory (the only source of truth)
    kube-apiserver-...            <- the switchboard (everything goes through it)
    kube-controller-manager-...   <- the desired-state chaser
    kube-scheduler-...            <- decides where each Pod goes
    coredns-... kube-proxy-... + the CNI pod (kindnet/calico/...): plumbing

## The sabotage

    NAME                         READY   STATUS    AGE
    lab-cap07-556f7d9488-82d69   1/1     Running   5s    <- the victim
    lab-cap07-556f7d9488-txlgs   1/1     Running   5s
    ...after the delete...
    lab-cap07-556f7d9488-797gw   1/1     Running   3s    <- born by itself
    lab-cap07-556f7d9488-txlgs   1/1     Running   38s

## Desired vs observed

    desired:  spec.replicas = 2
    observed: status.readyReplicas = 2

## The three questions

**a. List the control plane components with each one's role in a sentence.
Why is the kubelet not among the Pods?**

kube-apiserver: the only door — every read and write of cluster state passes
through it. etcd: the ledger where that state actually lives. kube-scheduler:
watches for Pods with no node assigned and picks one for them.
kube-controller-manager: runs the loops that compare desired and observed
state and issue corrections. The kubelet cannot be a Pod because it is the
component that RUNS Pods on each node: someone has to exist before the
containers do — it is a plain process on the node (systemd-managed, or a
process in the kind node container), chapter 5 style.

**b. Tell the story of step 4 from the controller's point of view.**

The ReplicaSet controller (inside kube-controller-manager) holds a simple
contract: this ReplicaSet must have 2 Pods. When the delete removed one, the
apiserver notified the watchers; the controller compared desired (2) with
observed (1) and created a new Pod object through the apiserver. The
scheduler saw a Pod with no node and assigned one; the kubelet on that node
saw a Pod assigned to it and started the container (through the chapter 5
chain). Nobody "restarted" the old Pod: a new one was manufactured to make
reality match the declaration.

**c. Who writes the spec and who writes the status? Why is this separation
the heart of the declarative model?**

The spec is written by the user (or by a controller acting on a user's
behalf): it is the desired state, an input. The status is written only by
the system — controllers and kubelet reporting what reality looks like. The
separation means you never command actions ("start a container"), you only
edit a document describing the end state; an army of loops works forever to
make status converge to spec. That is why Kubernetes survives crashes,
restarts and sabotage: the goal is stored, not the steps.
