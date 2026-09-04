# Chapter 7 - First contact - answers

## The completed TODOs

TODO 1 (7.2) sets replicas to 2. This is the desired state that the ReplicaSet
controller restores after a Pod disappears.

TODO 2 (7.1) selects alpine:3, giving the worker a real container to run.

TODO 3 (7.3) runs sleep infinity so both Pods remain alive and status can
converge to spec.

## Reflection answers

a. kube-apiserver is the only API entry point; etcd stores cluster state;
kube-scheduler assigns unscheduled Pods; kube-controller-manager runs the
reconciliation loops. The kubelet is a node process because it must exist in
order to start and supervise Pods.

b. The ReplicaSet controller observed desired 2 and actual 1 after deletion,
then created a new Pod object through the API server. The scheduler assigned it
and the kubelet materialised it. The old Pod was not restarted.

c. A user or controller writes spec as desired state. Kubernetes components
write status as their observation. Keeping these fields separate lets a loop
compare intent with reality and converge without replaying imperative steps.
