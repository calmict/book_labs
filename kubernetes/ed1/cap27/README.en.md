# Chapter 27 — The Escort (Istio and the service mesh)

> Exercise for **Chapter 27 — Istio and the service mesh** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Cloud Architect

## Objectives

By the end of this lab you will be able to:

- understand the problem a service mesh solves: encryption, retries, routing and traces today live inside every application, rewritten in every language; the mesh pulls them out and hands them to an escort;
- watch the escort attach itself to every pod (sidecar injection): the data plane is all the escorts (Envoy), the control plane (istiod) is the head office that briefs them;
- turn on automatic mTLS (identity and encryption without touching the app or managing a single certificate) and steer traffic from above: an 80/20 canary between two versions, decided by decree.

## Prerequisites

- Chapter 22 (NetworkPolicy: there network security was who-may-talk-to-whom; here it becomes identity and encryption on every call) and Chapter 25 (Prometheus: the mesh will feed it metrics and traces).
- kind and istioctl installed. WARNING: Istio installs cluster-wide CRDs and an injection webhook; as in chapter 26 the lab uses a dedicated throwaway cluster (book-labs-mesh), deleted at the end.
- In start/: mesh-app.yaml (given: two versions of an app + a client), mtls.yaml (given: PeerAuthentication STRICT) and canary.yaml (DestinationRule given, VirtualService with a TODO on the weights).

## Instructions

1. The escort attaches itself (injection). Create the cluster, install Istio and deploy the app:

       kind create cluster --name book-labs-mesh
       istioctl install --set profile=minimal -y
       kubectl apply -f mesh-app.yaml
       kubectl -n mesh wait --for=condition=Ready pod --all --timeout=120s
       kubectl -n mesh get pods -o custom-columns='NAME:.metadata.name,CONTAINERS:.status.containerStatuses[*].name'

   The mesh namespace carries the label istio-injection=enabled: every pod is born with TWO containers, yours (web / client) and istio-proxy — the Envoy escort, added automatically. The app did not change a single line.

2. Identity and encryption for free (mTLS). Order the namespace to speak only in mutual TLS:

       kubectl apply -f mtls.yaml
       kubectl -n outside run oclient --image=curlimages/curl:8.11.1 --restart=Never --command -- sleep infinity
       kubectl -n outside exec oclient -- curl -s -m 5 -o /dev/null -w "%{http_code}\n" http://web.mesh/
       kubectl -n mesh exec client -c client -- curl -s http://web/

   A client WITHOUT an escort (from the outside namespace, not injected) is refused: 000, connection reset — plaintext does not get in. The client WITH an escort gets through: the two escorts exchanged badges and encrypted everything, without you generating a single certificate.

3. Steer traffic from above (canary). Complete canary.yaml: in the VirtualService route 80% of the traffic to subset v1 and 20% to v2. Apply it and fire requests from the in-mesh client:

       kubectl apply -f canary.yaml
       kubectl -n mesh exec client -c client -- sh -c 'for i in $(seq 1 30); do curl -s http://web/; done' | sort | uniq -c

   About 24 v1 responses and 6 v2: the head office split the traffic by decree. Shift the weights (95/5, then 50/50, then 0/100) and you have done a canary rollout without touching the app. The same DestinationRule/VirtualService pair adds retries and circuit breaking (outlier detection): the escort retries a failed errand and stops knocking on a dead door.

4. The third pillar (observability). Every escort logs every trip: Istio exports metrics and traces (to chapter 25's Prometheus, to Jaeger, to Kiali) without instrumenting the app. We do not install it here, but it is why a mesh "sees" all the east-west traffic.

5. Tear the site down:

       kind delete cluster --name book-labs-mesh

## The questions for answers.md

- (a) The problem and the two planes (27.1–27.2). Why is putting network logic (TLS, retries, routing) inside every app a problem, and what changes by moving it into a sidecar escort? Distinguish data plane (the Envoy escorts) and control plane (istiod): who carries the packets and who dictates the rules? What exactly does injection do, and why does the app not notice?
- (b) mTLS (27.3). What did you prove by blocking the outside client with PeerAuthentication STRICT? Where do the identities and certificates come from if you created none? In what sense is this a different, complementary security layer to chapter 22's NetworkPolicy (who-may-talk-to-whom versus who-are-you-really)?
- (c) Traffic management and observability (27.4–27.5). How does the VirtualService do a canary without touching the app? What do retries and circuit breaking add, and why is it better to have them in the escort than in the code? Why is a mesh in the perfect position for observability (traces) compared to chapter 25's Prometheus alone?

## Definition of "done"

- [ ] Injection: every pod in the mesh namespace has two containers (app + istio-proxy).
- [ ] mTLS STRICT: the outside client is refused, the in-mesh client gets through.
- [ ] Canary: about 80/20 between v1 and v2 over some thirty requests.
- [ ] answers.md answers the three questions; the dedicated cluster has been deleted.
