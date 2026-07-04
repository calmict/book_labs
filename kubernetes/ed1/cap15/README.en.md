# Chapter 15 — The Release, the Disaster and the Comeback (Rollout and Rollback)

> Exercise for **Chapter 15 — ReplicaSet and Deployment** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- read the division of labour: the ReplicaSet as guardian of the count, the Deployment as orchestrator of ReplicaSets — with the old ReplicaSets kept at zero as historical memory;
- perform a zero-downtime rolling update and watch it pod by pod (maxSurge 1, maxUnavailable 0);
- survive a broken release: the rollout gets stuck but the service stays up, and kubectl rollout undo brings you back in an instant — understanding it is no magic, just the reconciliation loop again.

## Prerequisites

- Chapters 13-14 completed; the book-labs cluster running.
- The starting manifest start/shop.yaml with TODOs (replicas, strategy, image).

## Instructions

1. Open the shop. Complete start/shop.yaml: Deployment "shop", 3 replicas of alpine:3.19 (container sleeper, sleep infinity), and the zero-downtime strategy: RollingUpdate with maxSurge 1 and maxUnavailable 0. Apply and annotate the first revision:

       kubectl apply -f shop.yaml
       kubectl annotate deployment/shop kubernetes.io/change-cause="opening: alpine 3.19"
       kubectl rollout status deployment/shop

2. Who really rules. Look at what the Deployment owns:

       kubectl get replicaset -l app=shop
       kubectl get pods -l app=shop

   One ReplicaSet with a hash suffix, three pods with its prefix: the Deployment never touches pods — it commands ReplicaSets (chapter 13's chain). Note the ReplicaSet's name.

3. The release. Watch in one terminal (kubectl get pods -l app=shop -w), update from the other:

       kubectl set image deployment/shop sleeper=alpine:3.20
       kubectl annotate deployment/shop kubernetes.io/change-cause="release: alpine 3.20"
       kubectl rollout status deployment/shop

   In the watch: a new pod is born (the surge), an old one dies, and so on — never fewer than 3 active. When the round is over:

       kubectl get replicaset -l app=shop
       kubectl rollout history deployment/shop

   TWO ReplicaSets: the new one full, the old one kept at 0. Not garbage: it is the memory the rollback travels on.

4. The disaster. Release a version that does not exist:

       kubectl set image deployment/shop sleeper=alpine:3.99
       kubectl annotate deployment/shop kubernetes.io/change-cause="release: alpine 3.99 (oops)"
       kubectl rollout status deployment/shop --timeout=30s
       kubectl get pods -l app=shop

   The rollout gets stuck (ImagePullBackOff on the scout pod) but look closely: the 3 pods of 3.20 are still Running. The shop never closed — maxUnavailable 0 refused to touch the old guard until the new one was ready. Note the state.

5. The comeback. One command:

       kubectl rollout undo deployment/shop
       kubectl rollout status deployment/shop
       kubectl get deployment shop -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
       kubectl rollout history deployment/shop

   Back to alpine:3.20, in seconds (the pods were not even recreated: the 3.20 ReplicaSet was still there). Note the history: revision 2 was "reborn" with a new number, and the change-causes tell the whole story. Bonus: go back to the opening with kubectl rollout undo --to-revision=1 and verify the image.

6. The questions for answers.md: (a) the division of labour: what does the ReplicaSet do, and what can ONLY the Deployment do? Why do old ReplicaSets stay at 0 instead of disappearing? (b) the step 4 disaster: why did the service never go down, and what would have changed with maxUnavailable 1? Who would have noticed the problem in production (think: rollout status, the progressDeadline, the events)? (c) what does rollout undo REALLY do? (no magic: describe the move in terms of scaled ReplicaSets, and explain why it is still chapter 7's reconciliation loop)

7. Close the shop:

       kubectl delete deployment shop

## Definition of "done"

- [ ] You watched the rolling update pod by pod, never below 3 active.
- [ ] After the release you have two ReplicaSets (3 and 0) and the history with the change-causes.
- [ ] In the disaster: rollout stuck in ImagePullBackOff while the 3 pods of the previous version kept Running.
- [ ] After the undo the image is back to alpine:3.20 and the revision was reborn with a new number.
- [ ] answers.md answers the three questions and the Deployment has been removed.
