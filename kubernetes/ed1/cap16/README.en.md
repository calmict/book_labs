# Chapter 16 — The Registry Office: Names, Order and Disks That Survive

> Exercise for **Chapter 16 — StatefulSet and State Management** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- feel the difference between fungible Pods and Pods with an identity: the crowd is reborn with random names, diary-1 is reborn as diary-1;
- observe the strict ordering (0 → 1 → 2 going up, reverse going down) and the predictable DNS via a headless Service;
- prove that with volumeClaimTemplates each replica gets its OWN disk, and that the disk outlives the Pod — and even the deletion of the whole StatefulSet.

## Prerequisites

- Chapter 15 completed; the book-labs cluster running (the default StorageClass of kind/minikube is plenty).
- The starting manifest start/diary.yaml with TODOs (serviceName, volumeClaimTemplates, mount).

## Instructions

1. The crowd, for contrast. Create any Deployment and look at the names:

       kubectl create deployment crowd --replicas=3 --image=alpine:3 -- sleep infinity
       kubectl get pods -l app=crowd

   Random names, hash upon hash: fungible individuals. Delete one and see who takes its place: another random name. Nobody will miss it.

2. The registry office. Complete start/diary.yaml: a headless Service "diary" (clusterIP: None, already in the file) and a 3-replica StatefulSet using it as serviceName; each replica writes a diary line on awakening (the command is already in the file) to /data, mounted from a 10Mi volumeClaimTemplates (the TODOs guide you). Apply with the watch running in another terminal:

       kubectl get pods -l app=diary -w
       kubectl apply -f diary.yaml

   Watch the names and the order: diary-0, THEN diary-1 (only once 0 is Ready), THEN diary-2. No hashes: a registry office.

3. Rebirth with the same name. Delete the middle citizen:

       kubectl delete pod diary-1
       kubectl get pods -l app=diary

   The step 1 crowd replaced; here diary-1 is reborn as diary-1. And it did not come back empty-handed — read its diary:

       kubectl exec diary-1 -- cat /data/diary.txt

   Two lines: the one from before dying and the one from the awakening. The disk outlived the Pod.

4. One disk each. Look at the PVCs created by the template:

       kubectl get pvc

   data-diary-0, data-diary-1, data-diary-2: not one shared volume, but a personal disk per identity — which is what a database demands.

5. The disk outlives even the controller. Delete the WHOLE StatefulSet and check what remains:

       kubectl delete statefulset diary
       kubectl get pods -l app=diary
       kubectl get pvc

   Pods gone (in reverse order, if you were quick with the watch), but the PVCs are all still there: data is never deleted by accident. Now recreate the StatefulSet (re-apply diary.yaml) and reread diary-0's diary: every line of its previous life, plus the new one. Each identity found its OWN disk again.

6. The predictable address. From citizen 1, look citizen 0 up by name:

       kubectl exec diary-1 -- nslookup diary-0.diary.default.svc.cluster.local

   It resolves to the Pod's IP: with the headless Service every replica has a stable DNS name — that is how the members of a quorum cluster (chapter 8!) find each other. (The full name is mandatory: busybox's tiny resolver does not apply search domains.)

   The questions for answers.md: (a) fungible versus identity: use your evidence (names, rebirth, diary) and explain why a database cannot live in a Deployment; (b) why the 0→1→2 order (and the reverse descent) is vital for quorum systems — connect it to chapter 8; (c) the disk lifecycle: why do the PVCs survive the StatefulSet's deletion? Benefits, risks (orphan disks) and how to really clean up.

7. Tear everything down, disks included (a two-step cleanup this time, and now you know why):

       kubectl delete statefulset diary
       kubectl delete service diary
       kubectl delete deployment crowd
       kubectl delete pvc data-diary-0 data-diary-1 data-diary-2

## Definition of "done"

- [ ] You have the name contrast: random in the crowd, diary-N in the registry, born in 0→1→2 order.
- [ ] diary-1 was reborn as diary-1 and its diary held the line from its previous life.
- [ ] You saw the 3 personal PVCs, still alive after the StatefulSet's deletion, and the full diary after the recreation.
- [ ] The nslookup of the stable name resolves from inside.
- [ ] answers.md answers the three questions and the cleanup includes the PVCs.
