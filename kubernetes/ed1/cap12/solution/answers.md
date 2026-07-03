# Chapter 12 — Answers (model solution)

## The doctor's record

    liar   1/1   Running   2 (23s ago)   102s     <- RESTARTS climbing
    Warning  Unhealthy  kubelet  Liveness probe failed: cat: can't open
             '/tmp/healthy': No such file or directory
    Normal   Killing    kubelet  Container liar failed liveness probe,
             will be restarted
    (and, given time, Back-off restarting failed container)

## The bench

    healthy:  moody   10.244.0.45:80
    sick:     moody   <empty>          READY 0/1, RESTARTS still 0
    healed:   moody   10.244.0.45:80   (same pod, same IP, no restart)

## The pod that needs nobody

    /etc/kubernetes/manifests: etcd.yaml, kube-apiserver.yaml,
    kube-controller-manager.yaml, kube-scheduler.yaml   <- the control plane!
    hello-static-<node> appeared with no apply, came back with a NEW uid
    after the delete, and vanished only when the file was removed.

## The three questions

**a. Liveness versus readiness: describe the two fates you observed and
explain why a badly written liveness is dangerous.**

The failed liveness probe led to a kill and a fresh start: the kubelet
assumes the process is beyond saving and applies the only cure it has.
The failed readiness probe changed nothing about the process: the pod
went READY 0/1, its address left the Service endpoints, and it kept
running untouched — benched, not cured. That asymmetry is why a sloppy
liveness is dangerous: if the check can fail while the app is merely slow
(a long GC pause, a cold start, an overloaded dependency), the kubelet
kills a healthy process, the restart makes the app even colder, and the
back-off loop turns one slow moment into an outage. Rule of thumb: use
liveness only for truly unrecoverable states, and give it generous
thresholds; readiness is the probe that protects your traffic.

**b. Who resurrected hello-static, and how does it differ from chapter 7's
resurrection? Why is the control plane itself made of static pods?**

The kubelet did — alone. The pod's source of truth is the file in
/etc/kubernetes/manifests, not etcd: what lives in the API is a mirror
pod, published so the cluster can at least see it. Deleting the mirror
only deletes the reflection; the kubelet notices and republishes it (new
uid, same pod). In chapter 7 the resurrector was the ReplicaSet
controller comparing spec against etcd — a control-plane brain process.
And that is precisely why the control plane is made of static pods: the
apiserver cannot be created through an API that does not exist yet. The
kubelet, which needs nobody, bootstraps the very components everything
else depends on.

**c. What does the kubelet do when the node runs short of memory, and why
is eviction the sibling of chapter 3's OOM kill?**

The kubelet watches node-level signals (memory.available, disk, pids) and
when a threshold is crossed it starts evicting pods — gracefully, in a
deliberate order: pods exceeding their requests and with the lowest QoS
class (BestEffort, then Burstable) go first, Guaranteed last. It is the
same physics as chapter 3: memory is incompressible, someone must give
theirs back. But the OOM kill was the cgroup's own limit enforced by the
kernel with a SIGKILL to one process; eviction is the node's self-defence
enforced by the kubelet on whole pods, with grace periods and priorities.
Same verdict, different court: the kernel protects a cgroup boundary, the
kubelet protects the node — so that one greedy pod cannot take the
kubelet itself (and every neighbour) down with it.
