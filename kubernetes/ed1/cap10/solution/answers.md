# Chapter 10 — Answers (model solution)

## The professionals' heartbeat

    holderIdentity: book-labs-control-plane_8aec01a6-...
    renewTime: 2026-07-03T18:29:09Z -> 2026-07-03T18:29:13Z
    (read twice, four seconds apart: the leader keeps signing its presence)

## Your controller at work

    observed 1 < desired 2: creating one pod
    observed 2 = desired 2: nothing to do
    observed 3 > desired 2: deleting minictl-extra

## The duel

    observed 0 < desired 2: creating one pod      <- copy A
    observed 0 < desired 2: creating one pod      <- copy B, same instant
    observed 3 > desired 2: deleting minictl-12983
    observed 3 > desired 2: deleting minictl-12983  <- both chose the same victim
    (pods: 1 -> 3 -> 2: overshoot, then double-kill)

## The three questions

**a. Point at the observe, diff and act lines of your script and map them
onto what the ReplicaSet controller did in chapter 7.**

Observe is the kubectl get that counts the labelled pods; diff is the if
comparing OBSERVED with DESIRED; act is the kubectl run or kubectl delete
that closes the gap. The ReplicaSet controller in chapter 7 did exactly
this when we deleted a pod: its observe (via watch) reported one replica
missing, its diff compared against spec.replicas=2, its act created a new
Pod object through the apiserver. Same loop, different transport: ours
polls and shells out, the real one watches and calls the API — but the
logic is identical, and that is the whole point of the pattern.

**b. Why does polling not scale, and what do client-go's informers and
cache change?**

Polling pays a full request per controller per tick even when nothing
changed: cost grows with the number of controllers times the frequency,
and latency is on average half a tick. An informer opens one watch (the
chapter 9 stream), keeps a local cache synchronized by the events, and
wakes the controller only when something actually changed. Reads then hit
the local cache, not the apiserver; reactions are near-instant instead of
tick-late. One connection instead of a drumbeat of queries: that is how
hundreds of control loops coexist against a single apiserver.

**c. Describe the duel and how leader election prevents it: who renews the
lease, and what happens if it stops?**

Two identical copies, ticks aligned: both observed the same hole, both
created a pod (overshoot to 3), then both observed the same excess and
both deleted — even choosing the same victim. Nothing is wrong with either
copy: the flaw is that both act on the same desired state. Leader election
makes acting a privilege: each candidate tries to acquire a Lease object;
the one that succeeds writes its holderIdentity and must keep renewing
renewTime within leaseDurationSeconds. The others watch and do nothing.
If the leader stops renewing — crash, partition, freeze — the lease
expires and a bench-warmer takes over. One active loop at a time, with
automatic succession: the duel becomes a relay race.
