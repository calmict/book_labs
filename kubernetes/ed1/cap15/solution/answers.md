# Chapter 15 — Answers (model solution)

## The release

    shop-5c9d46bd4d   0   0   0     <- the 3.19 guard, kept at zero
    shop-6d765f89bd   3   3   3     <- the 3.20 guard, on duty
    REVISION  CHANGE-CAUSE
    1         opening: alpine 3.19
    2         release: alpine 3.20

## The disaster

    shop-6d765f89bd-mgw2z   1/1   Running            <- still serving
    shop-6d765f89bd-nc5gh   1/1   Running            <- still serving
    shop-6d765f89bd-z9xcf   1/1   Running            <- still serving
    shop-8d9c7f948-twxhm    0/1   ImagePullBackOff   <- the scout, stuck

## The comeback

    image now: alpine:3.20
    REVISION  CHANGE-CAUSE
    1         opening: alpine 3.19
    3         release: alpine 3.99 (oops)
    4         release: alpine 3.20      <- revision 2, reborn

## The three questions

**a. What does the ReplicaSet do, and what can only the Deployment do?
Why do old ReplicaSets stay at 0 instead of disappearing?**

The ReplicaSet knows one job: keep N pods matching a template alive — the
chapter 7 loop, nothing more. It cannot update anything: change the
template and you simply have a different ReplicaSet. The Deployment is the
layer that knows about TIME: it creates a new ReplicaSet per template
version and choreographs the handover, scaling one up and the other down
within the strategy's budget. The old ReplicaSets at zero are the
revisions themselves: each one holds a complete, ready-to-run copy of a
past template. Deleting them would delete the very possibility of a fast
rollback (their number is capped by revisionHistoryLimit).

**b. Why did the service never go down during the disaster, and what would
have changed with maxUnavailable 1? Who notices such a problem in
production?**

With maxUnavailable 0, the Deployment may kill an old pod only after a new
one is Ready. The 3.99 scout never became Ready, so the choreography froze
at the first step: one extra pod stuck in ImagePullBackOff and the three
3.20 pods untouched. With maxUnavailable 1 the Deployment would have
killed one old pod immediately — running the disaster with 2 replicas
instead of 3, real capacity lost for nothing. In production the alarm
comes from the deployment's conditions: after progressDeadlineSeconds the
condition Progressing turns to ProgressDeadlineExceeded, which pipelines
(kubectl rollout status exits non-zero) and monitors pick up — plus the
ImagePullBackOff events, which chapter 9's watchers stream to whoever
listens.

**c. What does rollout undo really do, in terms of scaled ReplicaSets?**

It edits the Deployment's pod template back to the previous revision's
template — nothing else. From there, the usual machinery runs: the
template now matches the existing 3.20 ReplicaSet, so the Deployment
scales that one up and the broken one down, within the same strategy
budget. That is why it was near-instant (the ReplicaSet and even its pods
were still there) and why the history shows a new revision number: undo
is not time travel, it is a new forward change whose content happens to be
old. Chapter 7's loop never stopped being the only engine — undo just
hands it a desired state it has already seen.
