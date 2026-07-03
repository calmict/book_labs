# Chapter 11 — Answers (model solution)

## The signature and its absence

    witness:  Normal  Scheduled  default-scheduler  Successfully assigned
              default/witness to book-labs-sched-worker
    bypass:   (no Scheduled event at all)

## The sieve

    picky, while Pending:
    Warning  FailedScheduling  default-scheduler  0/3 nodes are available:
    1 node(s) had untolerated taint(s), 2 node(s) didn't match Pod's node
    affinity/selector.
    picky, after the label:  Running on book-labs-sched-worker2

(read that message closely: it already tells the whole chapter — two nodes
rejected by the selector, one by a taint)

## The spread and the third replica

    spread-...-fsh5c   Running   book-labs-sched-worker
    spread-...-pvpnv   Running   book-labs-sched-worker2
    spread-...-wqk8n   Pending   <none>
    ...after the toleration...
    spread-...-wcfjj   Running   book-labs-sched-worker
    spread-...-m9q77   Running   book-labs-sched-worker2
    spread-...-rks6x   Running   book-labs-sched-control-plane

## The three questions

**a. What does the scheduler actually do, and what did you prove with the
bypass Pod? Who executed that Pod, if the scheduler never saw it?**

The scheduler does exactly one thing: for each Pod with an empty nodeName,
it picks a node (filtering, then scoring) and writes the decision back
through the apiserver. It does not pull images, start containers, or watch
them run. The bypass Pod proves it: with nodeName already filled in, the
scheduler had no work to do and left no Scheduled event — yet the Pod ran
anyway, because the kubelet of that node saw a Pod assigned to it and
executed it through the chapter 5 chain. Deciding and executing are two
different jobs, held by two different components.

**b. Tell the journey of the picky Pod: what kept it Pending, what
unblocked it, and where do filtering and scoring act?**

Its nodeSelector demanded disk=ssd, and the filtering phase discarded all
three nodes: two workers for the missing label, the control plane for its
taint — the FailedScheduling event lists both reasons. With zero survivors
there is nothing to score, so the Pod stayed Pending, re-evaluated at every
change. The kubectl label was that change: one worker passed the filter,
and with a single survivor scoring was trivial. Filtering decides who is
eligible; scoring ranks the eligible; a Pending pod with that event means
the filter returned an empty list.

**c. Explain the opposite directions of affinity and taints using the
third replica as evidence: what was it missing before the toleration?**

Affinity and selectors are expressed by the Pod: "I want nodes like this" —
they attract a Pod towards matching nodes. A taint is expressed by the
node: "keep away from me unless you carry a permission" — it repels by
default. The third replica satisfied every attraction rule it had (the
anti-affinity only forbade the two occupied workers), yet it stayed
Pending: the free node was repelling it. Nothing on the Pod pointed away
from the control plane; what was missing was the written permission — the
toleration matching the control-plane taint. Adding it did not attract the
Pod there; it merely stopped the rejection, and the scheduler did the rest.
