# Chapter 27 — Answers (model solution)

## Injection

    POD                       CONTAINERS
    client                    client,istio-proxy
    web-v1-...                istio-proxy,web
    web-v2-...                istio-proxy,web

## mTLS STRICT

    outside (no sidecar) -> web.mesh: REFUSED (000, connection reset)
    inside  (with sidecar) -> web:    v1  (over automatic mutual TLS)

## Canary

    25 v1
     5 v2
    (~80/20 over 30 requests)

## The three questions

**a. The problem and the two planes (27.1-27.2): why is network logic in
every app a problem, what changes with a sidecar, and what is the
difference between data plane and control plane?**

Every service already needs the same cross-cutting network behaviour: TLS,
retries with backoff, timeouts, load balancing, circuit breaking, request
tracing. When that logic lives INSIDE each app, it gets re-implemented in
every language and framework, drifts between teams, and can only be changed
by rebuilding and redeploying the app — so in practice it is done
inconsistently or not at all. A service mesh pulls all of it OUT of the app
and into a sidecar: an Envoy proxy injected next to every container that
transparently intercepts all inbound and outbound traffic. The app keeps
making a plain http://web/ call; the sidecar is what actually encrypts it,
retries it, routes it and reports it. The two planes divide the work: the
DATA PLANE is the fleet of Envoy sidecars that carry the packets and enforce
the rules on every hop; the CONTROL PLANE (istiod) carries no user traffic
at all — it configures the sidecars, distributing routing rules, issuing
certificates, and pushing updates. Injection is a mutating admission webhook
(chapter 23's admission world): when a pod is created in a namespace labelled
istio-injection=enabled, the webhook rewrites the pod spec to add the
istio-proxy container (and an init container that sets up iptables so all
traffic is redirected through it). The app does not notice because nothing
in ITS container changed — the redirection happens in the pod's network,
around it.

**b. mTLS (27.3): what did STRICT prove, where do the identities and
certificates come from, and how does this differ from and complement
chapter 22's NetworkPolicy?**

Applying PeerAuthentication STRICT told every sidecar in the mesh namespace
to accept only mutually-authenticated TLS connections. The outside client
had no sidecar, so it spoke plaintext, and it was refused (connection reset,
000) — proving that mTLS is really being enforced, not just offered. The
in-mesh client got through because its sidecar and the server's sidecar
performed a mutual TLS handshake transparently. You created no certificates:
istiod acts as a certificate authority and issues each workload a short-lived
X.509 certificate carrying a SPIFFE identity
(spiffe://cluster/ns/mesh/sa/default...) derived from its ServiceAccount, and
rotates it automatically. This is a different and complementary layer to a
NetworkPolicy. A NetworkPolicy (chapter 22) works at L3/L4 by IP and label
selector: who MAY connect to whom. It cannot tell whether the caller is
really who it claims — an attacker who lands on an allowed IP is trusted.
mTLS works at L7 by cryptographic identity: who the caller REALLY is, proven
by a certificate, with the traffic encrypted on the wire. You want both:
NetworkPolicy to shrink who can even attempt a connection, mTLS to guarantee
that whoever does connect is authenticated and unsniffable.

**c. Traffic management and observability (27.4-27.5): how does a canary
work without touching the app, what do retries and circuit breaking add,
and why is a mesh well placed for tracing?**

The canary is pure configuration read by the sidecars. The DestinationRule
declares two subsets of the web service, v1 and v2, distinguished by the
version label; the VirtualService says "send 80% of calls to subset v1 and
20% to subset v2". The client's sidecar enforces that split on every request
to web, so 30 calls come back roughly 24 v1 / 6 v2 — and the app made the
exact same http://web/ call throughout. Shifting the weights (95/5, 50/50,
0/100) is a canary rollout with no rebuild and instant rollback. Retries and
circuit breaking live in the same place: the VirtualService can retry a
failed request a few times with a timeout, and the DestinationRule's outlier
detection can eject an endpoint that keeps failing (stop knocking on a dead
door). Having these in the escort rather than in the code means every
service gets them uniformly, in every language, tunable at runtime without a
deploy. And the mesh is the ideal place for observability because ALL
east-west traffic already passes through the sidecars: they can emit metrics
(to chapter 25's Prometheus) and distributed traces (to Jaeger, visualised
in Kiali) for every hop without a single line of instrumentation in the
apps — the escort was already carrying every letter, so it can log every
one.
