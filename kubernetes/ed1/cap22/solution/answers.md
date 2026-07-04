# Chapter 22 — Answers (model solution)

## The open corridor

    app   -> safe: gioielli
    guest -> safe: gioielli

## The inversion

    app   -> safe: (timeout)
    guest -> safe: (timeout)
    -> the CNI enforces: the walls are real

## The nameplate and the silence

    app   -> safe: gioielli   (role=app, port 8080)
    guest -> safe: (timeout)  (no role, no entry)
    safe  -> app:  (timeout)  (egress denied: no calls out)

## The three questions

**a. Why is the flat network THE problem, what does the empty podSelector
say, and why does the grammar contain only permissions?**

By default every pod can reach every other pod in the whole cluster: the
flat network is convenient and catastrophic — one compromised pod has a
clear line of sight to the database, the secrets store, the neighbour's
API. Zero-trust inverts the assumption. The empty podSelector {} means
"every pod in this namespace", and with policyTypes: Ingress and no
ingress rules it grants zero inbound permissions: default deny in three
lines. The grammar has only permissions because a pod is denied the
moment ANY policy selects it, unless a rule explicitly allows the traffic
— the deny is never written, it is the absence of an allow. That makes
policies additive and safe to compose: you can only ever widen access by
adding, never accidentally punch a hole by ordering.

**b. Read your three policies as a network contract. What would it take
to let guest in, and what does that say about the model?**

deny-all: nobody talks to anybody (ingress). allow-app: pods with role=app
may reach app=safe on TCP 8080 — and only that. no-exfiltration: app=safe
may open no outgoing connection. To let guest in you have two roads, and
the choice is the lesson. You could edit allow-app to also admit guest —
or you could simply relabel guest with role=app, and it would walk
straight in without touching any policy. That is the point of
label-based, identity-driven networking: the firewall rule follows the
IDENTITY, not the IP or the hostname. Powerful and double-edged — whoever
can set labels can grant network access, so in production labels are as
security-sensitive as the policies themselves.

**c. Who realises the policies? The enforcement test, the CNI's role, and
the DNS caveat.**

The apiserver only stores NetworkPolicy objects; the CNI plugin is what
turns them into real packet filters on each node (iptables/eBPF rules,
chapter 6's world). Not every CNI does: some ignore the objects entirely,
which is why the enforcement test — apply deny-all, confirm the traffic
actually stops — is a hygiene ritual, not paranoia. It is the exact
chapter 19 déjà vu: an accepted object is a wish, and without an executor
(here Calico, Cilium, or recent kindnet) the wish does nothing while
lulling you into false safety. The egress caveat follows from the same
literalness: an egress default-deny blocks ALL outbound traffic, DNS
included, so a pod that resolves names before connecting will fail
mysteriously — the fix is an explicit egress rule to kube-dns on port 53,
which is why real-world egress policies are trickier than ingress ones.
