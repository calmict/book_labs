# Chapter 9 — Knock at the Four Gates (the API Server, Bare-Handed)

> Exercise for **Chapter 9 — API Server: The Single Source of Truth** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- talk to the API server without kubectl, with plain curl, and recognise groups, versions and resources of the REST API;
- consciously walk a request through its gates: rejected at authentication (401), rejected at authorization (403), rejected by admission (quota) and finally accepted;
- use a watch to see, streamed live, the events that keep the cluster in sync.

## Prerequisites

- Chapters 7-8 completed; the chapter 7 book-labs cluster running (kubectl get nodes must answer).
- curl and base64 (present on any Linux).

## Instructions

1. The switchboard answers without kubectl too. In one terminal open the tunnel:

       kubectl proxy

   and in a second terminal browse the REST API like a website (9.1):

       curl -s http://127.0.0.1:8001/api
       curl -s http://127.0.0.1:8001/apis | head -30
       curl -s http://127.0.0.1:8001/apis/apps/v1 | head -30

   Recognise the "core" group (/api/v1) and the named groups (apps, batch...): the same coordinates as chapter 7's kubectl api-resources.

2. First gate: knocking with no papers. Get the server's real address and show up with no credentials:

       kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
       curl -sk https://<that-address>/api/v1/namespaces

   A 401/403 answer for the anonymous user: the authentication gate is shut. (The -k only skips the CA check for now.)

3. Papers in hand. Extract your certificates from the kubeconfig and show up again:

       kubectl config view --raw --minify -o jsonpath='{.users[0].user.client-certificate-data}' | base64 -d > client.crt
       kubectl config view --raw --minify -o jsonpath='{.users[0].user.client-key-data}' | base64 -d > client.key
       kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > ca.crt
       curl -s --cert client.crt --key client.key --cacert ca.crt https://<address>/api/v1/namespaces | head -15

   You are in: kubectl has never done anything else. (With minikube the certificates are already files on disk: you will find paths instead of data in the kubeconfig.)

4. Second gate: authenticated does not mean authorized. Ask the cluster what you may do, then impersonate a humbler identity:

       kubectl auth can-i create pods
       kubectl get pods --as=system:serviceaccount:default:default

   Forbidden: the request got in (authenticated!) but the second gate turned it away. Note the difference from step 2's 401.

5. Third gate: admission. Even the authenticated and authorized can be rejected on the merits. Build the bouncer:

       kubectl create namespace quota-lab
       kubectl create quota one-pod-only --hard=pods=1 -n quota-lab
       kubectl run sleeper1 -n quota-lab --image=alpine:3 -- sleep infinity
       kubectl run sleeper2 -n quota-lab --image=alpine:3 -- sleep infinity

   The second Pod is rejected with "exceeded quota": that is the ResourceQuota admission plugin, speaking AFTER the first two gates. Reread the error: it is a 403, but of a different nature than step 4's.

6. The secret of synchronisation: the watch (9.4). With step 1's proxy still running:

       curl -sN "http://127.0.0.1:8001/api/v1/namespaces?watch=1"

   and from the other terminal create and delete a namespace:

       kubectl create namespace watch-lab
       kubectl delete namespace watch-lab

   Watch the stream: ADDED, MODIFIED, DELETED events in real time. This connection — not polling — is what keeps controllers, scheduler and kubelet in sync. Close the curl with Ctrl-C.

7. Answer in answers.md and tear down:

       kubectl delete namespace quota-lab
       rm -f client.crt client.key ca.crt

   (and stop kubectl proxy with Ctrl-C). The three questions: (a) reconstruct a request's journey through the gates of §9.2 using the evidence you collected: which gate does step 2's 401/403 correspond to, which one step 4's Forbidden, which one step 5's exceeded quota? (b) 401 versus 403: who issues them and what different things do they say? (c) why is step 6's watch more efficient than polling, and what does it have to do with chapter 7's reconciliation loop?

## Definition of "done"

- [ ] You browsed /api and /apis via curl and recognised groups and versions.
- [ ] You collected the full sequence: rejected as anonymous → 200 with certificates → Forbidden while impersonating → exceeded quota.
- [ ] You saw watch-lab's ADDED and DELETED events in the watch stream.
- [ ] answers.md answers the three questions.
- [ ] quota-lab namespace removed, extracted certificates deleted, proxy closed.
