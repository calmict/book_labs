# Chapter 8 — Answers (model solution)

## The three members and their leader

    ENDPOINT                   ID                ...  IS LEADER  RAFT TERM
    https://172.19.0.4:2379    2dee8f8700ce2106       false      2
    https://172.19.0.6:2379    6f1e1de96aea0868       true       2    <- leader
    https://172.19.0.5:2379    9cb367f7c8709cc6       false      2

## A namespace is a key

    /registry/namespaces/raft-lab

## The election

    (leader's node paused; asked to a survivor)
    Failed to get the status of endpoint https://172.19.0.6:2379 (...)
    https://172.19.0.4:2379    ...   true    3     <- new leader, new term
    https://172.19.0.5:2379    ...   false   3

(the raft term increased by one: that is the signature of an election)

## The frozen cluster

    # with 2 members frozen
    Unable to connect to the server: context deadline exceeded
    # after the unpause, within seconds
    raft-lab   Active   ...and three members with exactly one leader again

## The three questions

**a. Why do 3 members tolerate the loss of only 1? How many would a
5-member cluster tolerate? Write the general rule, and explain why 2
members are worse than 1.**

Every decision (a write, an election) requires the agreement of a strict
majority: floor(n/2)+1. With 3 members the majority is 2, so one loss is
survivable and the second is fatal. With 5 the majority is 3: it tolerates
2 losses. The general rule: n members tolerate floor((n-1)/2) failures. Two
members are worse than one because the majority of 2 is 2: a single loss
freezes everything, exactly like with 1 member — but now you have twice the
hardware and twice the failure probability, with zero tolerance gained.
That is why etcd clusters always have an odd size.

**b. Tell the story of the election: who elected the new leader, and on
what basis? Why did Kubernetes keep answering as if nothing happened?**

When the leader stopped answering heartbeats, the two survivors waited out
their election timeout, then one of them stood as a candidate, incremented
the term and asked for votes; members grant their vote to a candidate whose
log is at least as up-to-date as their own. Two votes out of three is a
majority: new leader, in well under a second. Kubernetes never noticed
because the apiservers do not care which member is the leader — the etcd
client library reroutes to the current leader — and 2 members still form a
quorum, so reads and writes kept flowing.

**c. During the freeze, did the containers already running on the surviving
node keep running? Why does a frozen brain not stop the arms?**

Yes. The kubelet and the container runtime on each node keep running what
they were already told to run: containers do not need etcd to exist from
one second to the next. What stops is change: no new Pods, no rescheduling,
no self-healing, because every decision needs to be read from and written
to the frozen source of truth. It is chapter 7's lesson from the dark side:
the desired state is stored, not continuously re-commanded — so while the
brain is frozen, the arms simply keep doing the last thing agreed upon.
