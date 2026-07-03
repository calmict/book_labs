# Chapter 12 — The Ship's Doctor: Probes, Restarts and the Pod That Resurrects Alone

> Exercise for **Chapter 12 — The Worker Node Components** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- watch the kubelet play doctor: a failing liveness probe and the container restarted, with the restart count and the growing back-off;
- tell the two fates apart: liveness (restart) versus readiness (out of the traffic rotation, no restart) — watching a Service's endpoints empty and refill;
- prove that the kubelet needs nobody: a static pod created by placing a file on the node, which resurrects even if you delete it from the API.

## Prerequisites

- Chapters 7-11 completed; the book-labs cluster running.
- The starting manifests in start/ have TODOs on the probes.
- You must be able to enter the node (with kind, and minikube on the Docker driver: docker exec <node-name>).

## Instructions

1. The lying app. Complete start/pod-liar.yaml: the container creates /tmp/healthy, sleeps twenty seconds, then removes it (while continuing to run); the TODO is the exec livenessProbe (cat /tmp/healthy, periodSeconds 5, initialDelaySeconds 5). Apply and watch the doctor at work:

       kubectl apply -f pod-liar.yaml
       kubectl get pod liar -w

   Wait a couple of minutes: RESTARTS climbs, and climbs again. Stop the watch and read the medical record:

       kubectl describe pod liar

   Among the events: Unhealthy (the failed probe), Killing (the cure), Started (the relapse), and eventually Back-off (the doctor losing patience: restarts get spaced out).

2. The moody patient. Complete start/pod-moody.yaml: a container that creates /tmp/ready at startup, a readinessProbe checking it (test -f, periodSeconds 3, failureThreshold 2), plus the Service already present in the file. Apply and look at who receives traffic:

       kubectl apply -f pod-moody.yaml
       kubectl get endpoints moody

   The pod's IP is there. (kubectl warns that Endpoints is deprecated in favour of EndpointSlice: the historic Endpoints is perfectly fine — and more readable — for observing the phenomenon; you will meet its evolution in the Services chapter.) Now make it sick without killing it:

       kubectl exec moody -- rm /tmp/ready
       kubectl get pod moody
       kubectl get endpoints moody

   READY 0/1, endpoints empty — but RESTARTS unchanged: no restart at all. Readiness does not cure, it benches. Heal it:

       kubectl exec moody -- touch /tmp/ready
       kubectl get endpoints moody

   Back in the game. Two probes, two fates: write the difference down.

3. The kubelet needs nobody. Find the node and look into its static manifests folder:

       kubectl get nodes
       docker exec <node-name> ls /etc/kubernetes/manifests

   Recognise the tenants? apiserver, etcd, scheduler, controller-manager: the control plane itself is made of static pods (that is how a cluster is born before the API exists). Now add yours:

       docker cp start/static-hello.yaml <node-name>:/etc/kubernetes/manifests/
       kubectl get pods

   hello-static-<node-name> appeared: no kubectl apply, no scheduler, no controller — the kubelet saw the file and acted.

4. Resurrection without a controller. Try deleting it from the API:

       kubectl delete pod hello-static-<node-name>
       kubectl get pods

   Already back. In chapter 7 the resurrector was the ReplicaSet controller; here there is no Deployment: what you see in the API is only the mirror of what the kubelet runs on its own. As long as the file sits in the folder, the pod exists. Remove the file and verify it vanishes:

       docker exec <node-name> rm /etc/kubernetes/manifests/static-hello.yaml
       kubectl get pods

5. The questions for answers.md: (a) liveness versus readiness: describe the two fates you observed (restart vs bench) and explain why a badly written liveness is dangerous (chain restarts of an app that was merely slow); (b) who resurrected hello-static, and how does it differ from chapter 7's resurrection? Why is the control plane itself made of static pods? (c) eviction: what does the kubelet do when the node runs short of memory, and why is it the sibling of chapter 3's OOM kill? (think: incompressible resource, but this time the defence protects the whole node)

6. Tear down the lab:

       kubectl delete pod liar moody
       kubectl delete service moody

   (the static pod is already gone with its file at step 4)

## Definition of "done"

- [ ] liar's RESTARTS climbed at least twice and the events show Unhealthy, Killing and the Back-off.
- [ ] moody's endpoints emptied and refilled without any pod restart.
- [ ] hello-static appeared without an apply, resurrected after the delete, and vanished when the file was removed from the node.
- [ ] answers.md answers the three questions.
- [ ] Lab pod and Service removed.
