# Chapter 18 — Answers (model solution)

## The dead direct number

    helpdesk-...-qbp9l   10.244.0.112   -> deleted
    helpdesk-...-zhbjf   10.244.0.114   <- the replacement, new number
    (wget to 10.244.0.112: download timed out)

## The switchboard

    CLUSTER-IP 10.96.24.249, and over ten calls:
    5 helpdesk-5955f6ddc-qwdvd
    5 helpdesk-5955f6ddc-zhbjf

## The investigation

    ip addr | grep 10.96.24.249   -> nothing, on any node
    -A KUBE-SERVICES -d 10.96.24.249/32 ... -j KUBE-SVC-3CAWLN66V3JY23B3
    -A KUBE-SVC-... --probability 0.50000000000 -j KUBE-SEP-ZKUV...
    -A KUBE-SEP-... -j DNAT --to-destination 10.244.0.111:8080

## The phonebook and the name

    helpdesk-8lx9k   IPv4   8080   10.244.0.111,10.244.0.114          (2)
    helpdesk-8lx9k   IPv4   8080   10.244.0.111,10.244.0.114,.0.115   (3)
    helpdesk.default.svc.cluster.local -> 10.96.24.249  (the ClusterIP)

## The three questions

**a. Reconstruct a packet's journey: who rewrites what, where does the
DNAT happen, and why must the ClusterIP not exist on any interface?**

The client resolves the name to the ClusterIP and sends a packet to
10.96.x.x:80. On the very node where the client pod lives, before the
packet ever leaves for the network, netfilter's KUBE-SERVICES chain
matches the destination, a KUBE-SVC rule tosses the coin, and a KUBE-SEP
rule performs the DNAT: destination rewritten to a real pod IP and port.
From then on it is ordinary chapter 6 routing (veth, bridge, CNI), and
conntrack remembers the rewrite so the reply gets un-rewritten on the way
back. The ClusterIP must not exist on any interface because no packet is
ever meant to ARRIVE there: it is a matching key, not an address — if a
host owned it, it would answer instead of forwarding, and the whole
distributed trick (every node rewriting locally) would collapse into a
single box.

**b. Netfilter's coin: how do you read the --probability rules, and what
happens when a pod dies or fails readiness?**

Rules are tried in order, so the probabilities are conditional: with two
backends, the first rule fires with probability 0.5 and the second is the
fallthrough (the remaining 100%). With three, you see 0.333..., then 0.5,
then the fallthrough — each reads "one out of the remaining candidates".
When a pod dies or its readiness fails, the kubelet's report empties its
entry from the EndpointSlice (chapter 12's bench); the EndpointSlice
controller writes the new list through the apiserver, every kube-proxy
receives it on its watch (chapter 9) and regenerates the chains: one
KUBE-SEP disappears and the probabilities are redistributed. No traffic
is ever load-balanced to a corpse — as long as the phonebook is faster
than your clients.

**c. The stability hierarchy: normal versus headless Service — what does
DNS resolve in each case, and when do you want one or the other?**

A normal Service resolves to its ClusterIP: one name, one virtual number,
the switchboard picks the operator — perfect for fungible backends
(chapter 15's crowd), where the caller must not care who answers. A
headless Service (clusterIP: None, chapter 16) resolves to the individual
pod IPs, and each pod gets its own stable DNS name: no switchboard, no
coin — the caller WANTS a specific individual, which is exactly what
databases and quorum members need. Rule of thumb: interchangeable workers
behind a ClusterIP; named citizens behind a headless Service. In both
cases the name outlives every IP involved: the top of the stability
hierarchy is always DNS.
