# Chapter 17 — The Three Trades: One per Node, Until Done, On Schedule

> Exercise for **Chapter 17 — DaemonSet, Job and CronJob** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- read the DaemonSet as a geographic contract: no replicas field — the cluster decides the count, one watchman per node (with chapter 11's toleration to cover the control plane too);
- meet the first object that wants to finish: the Job, with the difference between restarting a container and retrying a Pod (backoffLimit), and the honest failure of a Job that cannot make it;
- watch a CronJob punch the clock: the CronJob → Job → Pod chain, one minute after the apply.

## Prerequisites

- Chapters 11-16 completed.
- **kind** and Docker: the 3-node cluster is needed (start/kind-workers.yaml provided, name book-labs-crew) — a DaemonSet with no extra nodes has nothing to say. Mind the inotify limits ([SETUP.md](../../SETUP.md)).
- Three manifests in start/ with TODOs: watchman.yaml, jobs.yaml, tick.yaml.

## Instructions

1. The yard. Create the 3-node cluster:

       kind create cluster --config start/kind-workers.yaml
       kubectl get nodes

2. One watchman per node. Complete start/watchman.yaml: a DaemonSet "watchman" (alpine:3, sleep infinity) — and note what is NOT among the TODOs: no replicas. Apply and count:

       kubectl apply -f watchman.yaml
       kubectl get pods -l app=watchman -o wide

   Two watchmen, one per worker. But there are three nodes: who is missing, and why? (Chapter 11 already told you: the control plane's taint.) Add the toleration for node-role.kubernetes.io/control-plane to the template and re-apply:

       kubectl get pods -l app=watchman -o wide

   Three watchmen, three nodes. Now the proof of the geographic contract: delete a worker's watchman and watch where it is reborn:

       kubectl delete pod <a-worker-watchman>
       kubectl get pods -l app=watchman -o wide

   Same node. Not a count to restore (chapter 7): a map to honour.

3. Work that finishes. Complete start/jobs.yaml: two Jobs — "countdown" counts down from 5 and exits 0 (restartPolicy Never is in the TODOs: a Job cannot have Always... ask yourself why); "flaky" always exits 1, backoffLimit 2. Apply and watch the two fates:

       kubectl apply -f jobs.yaml
       kubectl get jobs -w

   countdown reaches COMPLETIONS 1/1 and its pod stays there, Completed, as a receipt (read its logs: kubectl logs job/countdown). flaky retries instead: watch the pods multiply (2 retries after the first attempt), then the Job gives up:

       kubectl get pods -l job-name=flaky
       kubectl describe job flaky | grep -A3 Conditions

   Failed, with the reason: BackoffLimitExceeded. The first object of the series with the right to fail for good.

4. Work on schedule. Complete start/tick.yaml: a CronJob "tick", scheduled every minute, printing the date. Apply and wait for the punch (up to a minute):

       kubectl apply -f tick.yaml
       kubectl get jobs -w

   On the minute: a Job tick-<timestamp> is born, which spawns a Pod, which prints and dies. Read the chain of command:

       kubectl get jobs
       kubectl logs job/<the-newborn-job>

   Chapter 13's delegation, one floor taller: CronJob → Job → Pod.

5. The full picture (§17.4): the questions close the trades table of the core objects.

   The questions for answers.md: (a) where is "how many" written in a DaemonSet? Explain the geographic contract with your evidence (the same-node rebirth, the third watchman arriving with the toleration); (b) the Job and its attempts: why is restartPolicy Always forbidden, what does backoffLimit count, and what is the difference between the kubelet restarting a container (chapter 12) and the Job creating a new Pod? (c) the trades table: for each of the 5 core objects (Deployment, StatefulSet, DaemonSet, Job, CronJob) write one line — who uses it, for what, and the question it answers ("how many copies?", "who are you?", "where?", "is it done?", "when?").

6. Tear the yard down:

       kind delete cluster --name book-labs-crew

## Definition of "done"

- [ ] watchman: 2 watchmen before the toleration, 3 after, and the same-node rebirth.
- [ ] countdown Completed with the counting logs; flaky Failed with BackoffLimitExceeded after 3 pods.
- [ ] The CronJob's first punch: a tick-<timestamp> Job with the date in its logs.
- [ ] answers.md answers the three questions (trades table included).
- [ ] The book-labs-crew cluster has been deleted.
