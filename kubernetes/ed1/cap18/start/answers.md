# Chapter 18 — Answers

## The dead direct number

    # paste here the pod IPs before and after the delete

## The switchboard

    # paste here a few alternating wget answers and the CLUSTER-IP

## The investigation

    # paste here the (empty) interface search and the KUBE-SVC/KUBE-SEP
    # rules with --probability and DNAT

## The phonebook and the name

    # paste here the EndpointSlice before/after the scale,
    # and the nslookup resolving to the ClusterIP

## The three questions

**a. Reconstruct a packet's journey from client to operator: who rewrites
what, where does the DNAT happen, and why must the ClusterIP not exist on
any interface?**

_(your answer)_

**b. Netfilter's coin: how do you read the --probability rule with 2 and
3 backends, and what happens when a pod dies or fails readiness?**

_(your answer)_

**c. The stability hierarchy: normal versus headless Service — what does
DNS resolve in each case, and when do you want one or the other?**

_(your answer)_
