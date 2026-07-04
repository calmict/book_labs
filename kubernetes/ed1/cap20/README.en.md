# Chapter 20 — The Arranged Marriage (PV, PVC, StorageClass)

> Exercise for **Chapter 20 — Storage: PV, PVC, StorageClass and CSI** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- arrange a static marriage: a hand-made PV, a PVC asking for it, the 1:1 binding — and the spinster stuck Pending when the volumes run out;
- unleash dynamic provisioning: a PVC with a StorageClass and a PV born out of nowhere, signed by the provisioner;
- read the reclaim policies in practice: the dynamic PV dying with its claim (Delete) and the manual one left a widow, still guarding the dowry (Retain, Released state).

## Prerequisites

- Chapter 16 completed (you have met PVCs from the StatefulSet side).
- The book-labs cluster running; node access via docker exec (to verify the dowry on disk).
- Three manifests in start/: marriage.yaml (the PV and the writer are given, the "bride" PVC has the TODOs), spinster.yaml (given) and dynamic.yaml (TODO on the claim).

## Instructions

1. The arranged marriage. In start/marriage.yaml the PV "manual-pv" is given (50Mi, hostPath, storageClassName manual, reclaim Retain — read it carefully); complete the "bride" PVC (asking 30Mi of the manual class) and apply:

       kubectl apply -f marriage.yaml
       kubectl get pv,pvc

   bride is Bound to manual-pv: the claim found a volume satisfying request, accessModes and class. The file also holds a "writer" pod that mounts the bride and stores the dowry (/data/dote.txt): check it is Running.

2. The spinster. Apply the second claim, identical to the first:

       kubectl apply -f spinster.yaml
       kubectl get pvc

   Pending, forever: binding is 1:1 and the manual-class volumes are gone. "The PVC asks, the PV exists" — and when none exists, it waits.

3. The automatic matchmaker. Complete start/dynamic.yaml: a "cloud" PVC of 30Mi WITHOUT any storageClassName (the default class will answer); the file also holds a "tenant" pod mounting it — genuinely needed: look at the class's VOLUMEBINDINGMODE column. Apply and observe:

       kubectl apply -f dynamic.yaml
       kubectl get pvc cloud
       kubectl get pv
       kubectl get storageclass

   A new PV, named pvc-<uid>, created by the default StorageClass's provisioner (on kind: rancher.io/local-path): no administrator prepared it — a controller (chapter 10, as always) saw the claim and granted it. And with WaitForFirstConsumer the matchmaker waits to know WHERE the volume is needed before creating it: without the tenant, cloud would stay Pending. Compare the two PVs' RECLAIM POLICY columns: Retain for the manual one, Delete for the dynamic one.

4. Two different deaths. Delete the pods and every claim, then look at the volumes' fates:

       kubectl delete pod writer tenant
       kubectl delete pvc bride spinster cloud
       kubectl get pv

   The dynamic PV is gone (Delete: died with its claim). manual-pv is instead in the Released state: a widow, not remarriable (the late claim's claimRef stays engraved), but with the dowry intact. Verify it on the node:

       NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
       docker exec $NODE cat /tmp/manual-pv/dote.txt

   The writer's line is still there: Retain kept its promise.

5. The questions for answers.md: (a) the marriage: on which criteria does the binder marry a PVC to a PV, why is it 1:1, and what was the spinster waiting for? (b) the reclaim policies in practice: tell the two deaths of step 4 — when do you want Retain, what is the risk of the Delete default, and what does it take to make a Released PV Available again? (c) the three extension contracts: CSI is to storage what CRI (chapter 5) is to runtimes and CNI (chapter 6) to networking — why does Kubernetes define interfaces instead of implementations, and where did you see the provisioner-as-controller pattern at work?

6. Tear down the lab (the Released PV must be removed by hand — now you know why):

       kubectl delete pv manual-pv
       docker exec $NODE rm -rf /tmp/manual-pv

## Definition of "done"

- [ ] bride Bound to manual-pv, writer Running, spinster Pending forever.
- [ ] cloud Bound to a pvc-<uid> PV born from the provisioner, with RECLAIM POLICY Delete against the manual one's Retain.
- [ ] After the massacre of the claims: dynamic PV gone, manual-pv Released, and the dowry still readable on the node.
- [ ] answers.md answers the three questions.
- [ ] Released PV and node folder removed by hand.
