# Chapter 13 — Answers (model solution)

## The timeline of the relay

    TIME        SIGNATURE               REASON              OBJECT
    ...19Z      deployment-controller   ScalingReplicaSet   relay
    ...19Z      replicaset-controller   SuccessfulCreate    relay-6467d7f488
    ...19Z      default-scheduler       Scheduled           relay-...-8hhp6
    ...20Z      kubelet                 Pulled              relay-...-8hhp6
    ...20Z      kubelet                 Created             relay-...-8hhp6
    ...20Z      kubelet                 Started             relay-...-8hhp6

(the first three share the same second and may print shuffled; the logical
order is forced by the ownership chain: nobody can schedule a Pod that the
replicaset-controller has not created yet, and no ReplicaSet exists before
the deployment-controller scales it into being)

## The chain of ownership

    pod/relay-6467d7f488-9npbb -> replicaset/relay-6467d7f488 -> deployment/relay

## Below the API

    pid on the node: 20929
    /proc/20929/cgroup:
    0::/kubelet.slice/kubelet-kubepods.slice/kubelet-kubepods-besteffort.slice/
        kubelet-kubepods-besteffort-pod0e17bb9a....slice/cri-containerd-....scope
    (kubepods + the QoS class, besteffort: chapter 3's accountant, employed
     by the kubelet)
    pid namespace: pid:[4026534065]   (chapter 2's window, built by the runtime)

## The two cures

    after kill -9:      relay-...-fkg9w   1/1   Running   1 (3s ago)
    after the delete:   relay-...-snwqq   1/1   Running   0
    (same pod with RESTARTS up, then a brand-new name)

## The three questions

**a. The relay timeline: map each signatory to its chapter, and give the
logical order beyond the timestamps.**

deployment-controller and replicaset-controller are two loops inside the
controller-manager (chapter 10): the first saw a Deployment with no
ReplicaSet and created one; the second saw a ReplicaSet short of one Pod
and created it. default-scheduler (chapter 11) saw a Pod with no node and
bound it. The kubelet (chapter 12) saw a Pod bound to its node and pulled,
created, started the container through the runtime chain (chapter 5).
Every hand-off happened through the apiserver (chapter 9) and was recorded
in etcd (chapter 8) — no component ever spoke to another directly. The
logical order is dictated by creation dependencies, which is exactly why
it can be reconstructed even when the one-second timestamps tie.

**b. The two cures: who acted in each case, which signal gives it away,
and why are both levels of healing needed?**

The kill -9 murdered the process behind the API's back: only the kubelet,
watching container states through the PLEG, could notice — and its cure is
a container restart inside the same Pod: RESTARTS climbs, the name stays.
The kubectl delete removed the API object itself: the kubelet tears the
containers down obediently, and it is the ReplicaSet controller that finds
observed (0) below desired (1) and manufactures a new Pod: fresh name,
RESTARTS back to zero. Both levels are needed because they see different
things: the kubelet heals what dies on the node without the cluster
knowing; the controller heals what disappears from the cluster's desired
state. One repairs containers, the other repairs the count.

**c. What are ownerReferences for, and what do you expect if you delete
the ReplicaSet instead of the Pod?**

They are the wiring of delegation: each object points at the controller
that owns it, which is how the garbage collector knows what belongs to
what. Deleting the ReplicaSet triggers the cascade: the garbage collector
deletes the orphaned-to-be Pods that reference it. But the story does not
end there — the Deployment still declares one ReplicaSet's worth of pods,
so the deployment-controller notices the hole and recreates the ReplicaSet
(with a new name), which recreates the Pod. Same self-healing as ever, one
storey higher: kill any floor of the pyramid, and the floor above rebuilds
it. Only deleting the Deployment — the top owner — makes everything go for
good, cascading down the ownerReferences.
