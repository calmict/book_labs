# Chapter 14 — The Condo Pod: Two Tenants, One Invisible Janitor

> Exercise for **Chapter 14 — The Pod in Depth** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- demonstrate why the unit is the Pod and not the container: two containers talking over localhost and passing files on a shared volume;
- unmask the pause container: first from the namespace inodes on the node, then — turning the condo into glass — watching it appear as PID 1 inside the Pod;
- watch an init container play gatekeeper (the Init:0/1 phase live) and read the QoS class of three Pods from their resources — finding it again in chapter 3's cgroup hierarchy.

## Prerequisites

- Chapter 13 completed (crictl and the descent to the node no longer scare you).
- The book-labs cluster running; node access via docker exec.
- Three manifests in start/ with TODOs: condo.yaml, init.yaml, qos-trio.yaml. (The condo uses the busybox:stable image: its httpd gives us a two-kilobyte web server — alpine's busybox ships without it.)

## Instructions

1. The condo. Complete start/condo.yaml: a Pod with two containers and an emptyDir volume mounted by both on /www — "web" serves the folder with httpd (httpd -f -p 8080 -h /www), "writer" writes the date into it every two seconds (the TODOs guide the second container). Apply, then ask one tenant about the other:

       kubectl apply -f condo.yaml
       kubectl exec condo -c writer -- wget -qO- http://localhost:8080

   The writer just read, VIA LOCALHOST, a page served by the other container, whose content is the file the writer itself keeps writing on the volume: shared network and shared disk, in one shot. Try again a few seconds later: the date changes.

2. The evidence from the node (chapter 13's method). Find the PIDs of the two containers and compare their namespaces:

       NODE=$(kubectl get pod condo -o jsonpath='{.spec.nodeName}')
       W=$(docker exec $NODE crictl ps --name writer -q)
       H=$(docker exec $NODE crictl ps --name web -q)
       PW=$(docker exec $NODE crictl inspect -o go-template --template '{{.info.pid}}' $W)
       PH=$(docker exec $NODE crictl inspect -o go-template --template '{{.info.pid}}' $H)
       docker exec $NODE readlink /proc/$PW/ns/net /proc/$PH/ns/net
       docker exec $NODE readlink /proc/$PW/ns/pid /proc/$PH/ns/pid

   Same network inode (there is your shared localhost), different PID namespaces (each its own tree). And who keeps those namespaces alive if the tenants die? Look for the janitor:

       docker exec $NODE ps -ef | grep /pause

3. The glass condo. Add the line shareProcessNamespace: true to your condo.yaml (in the Pod spec), rename it condo-glass and apply. Then look at the other tenant... from inside:

       kubectl exec condo-glass -c writer -- ps aux

   They are all there: the writer, the other container's httpd and — as PID 1 — /pause. The invisible janitor of §14.2, seen without even descending to the node. Note who is PID 1 here and who it was in chapter 2.

4. The gatekeeper. Complete start/init.yaml: an initContainer "gatekeeper" that waits 8 seconds and writes /shared/gate on an emptyDir, and the main container that starts only afterwards (reads the file and sleeps). Apply with the watch on:

       kubectl apply -f init.yaml
       kubectl get pod init-demo -w

   Watch the sequence of states: Init:0/1 → PodInitializing → Running. The init container is sequential and dies accomplished; §14.3's sidecars (restartPolicy Always on the init) are its evolution that stays alive.

5. The three castes (14.5). Complete start/qos-trio.yaml: three sleeping Pods — no resources at all (poor), requests lower than limits (middle), requests equal to limits (royal). Apply and ask the cluster for the verdict:

       kubectl apply -f qos-trio.yaml
       kubectl get pod poor middle royal -o custom-columns='POD:.metadata.name,QOS:.status.qosClass'

   BestEffort, Burstable, Guaranteed: you never declared them — the apiserver deduced them from the resources. In chapter 13 you saw the cgroup path with kubepods-besteffort: this is where the castes become folders (and eviction priorities, chapter 12).

6. The questions for answers.md: (a) why the Pod and not the container: use your evidence (localhost, volume, identical net inodes, pause as PID 1) and explain what job the pause container does; (b) init container versus sidecar: what does the Init sequence guarantee, and when do you need a companion that stays alive instead? (c) the three castes: where does each one end up in the cgroup hierarchy, and in which order do they die when the node is under pressure (chapter 12)? Why does "Guaranteed" mean "more protected" rather than "faster"?

7. Tear down the lab:

       kubectl delete pod condo condo-glass init-demo poor middle royal

## Definition of "done"

- [ ] The wget from the writer returns the date written by the other container (shared localhost + volume).
- [ ] You have the inodes: identical net between the two containers, different pid, and you found the /pause process on the node.
- [ ] In condo-glass you saw /pause as PID 1 from inside the Pod.
- [ ] You observed the Init:0/1 phase and the three QoS verdicts (BestEffort, Burstable, Guaranteed).
- [ ] answers.md answers the three questions and the six Pods have been removed.
