# Chapter 19 — The Door and the Doorman (Ingress and Ingress Controller)

> Exercise for **Chapter 19 — Ingress and Ingress Controller** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- understand why Services (L4) are not enough: the Ingress reads what they cannot see — host and path;
- feel the separation of roles through an experiment: Ingress rules applied WITHOUT a controller do nothing — the object is the written request, the controller is who executes it;
- install ingress-nginx on kind and watch L7 routing live: two hosts on the same IP and port, each to its own app, and the default backend for strangers.

## Prerequisites

- Chapter 18 completed (Services and ClusterIP).
- **kind** and Docker: a dedicated cluster with the host's port 8081 mapped is needed (start/kind-ingress.yaml provided; if 8081 is taken, change it there). First chapter installing an external component: network access is needed to download ingress-nginx. (On minikube the path differs: the ingress addon plus minikube tunnel — here we stay on kind.)
- Two manifests in start/: apps.yaml (given complete) and ingress.yaml (the rules are the TODOs).

## Instructions

1. The building. Create the cluster with the mapped door and the two apps with their Services:

       kind create cluster --config start/kind-ingress.yaml
       kubectl apply -f start/apps.yaml
       kubectl get pods,svc

   Two tenants (uno and due, each answering with its own name) and their internal switchboards (chapter 18). But from outside the building, nobody reaches them.

2. The written request, with no doorman. Complete start/ingress.yaml: two host-based rules — uno.labs.local towards service uno, due.labs.local towards service due (the TODOs guide rules, host, backend). Apply and try knocking:

       kubectl apply -f ingress.yaml
       kubectl get ingress
       curl http://localhost:8081

   Connection refused, and the Ingress's ADDRESS column is empty. The rules are written, filed... and ignored: you declared an object that no controller realises. Kubernetes does not complain — it is chapter 10's pattern: objects are wishes, controllers are who grants them.

3. The doorman arrives. Install ingress-nginx in its kind flavour (pinned version):

       kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.0/deploy/static/provider/kind/deploy.yaml
       kubectl wait -n ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=300s
       kubectl get pods -n ingress-nginx

   Look at what the doorman is: a Deployment like any other (nginx plus a process watching Ingress objects — chapter 9 — and rewriting its own configuration).

4. The door works. Same port, same IP, two destinations:

       curl -H "Host: uno.labs.local" http://localhost:8081
       curl -H "Host: due.labs.local" http://localhost:8081
       curl http://localhost:8081

   app-uno, app-due, and a 404 for whoever does not say the right name: the L7 routing no Service can do (a Service only sees IP and port; the Host header lives inside HTTP). Look at kubectl get ingress again: ADDRESS is now populated.

5. The anatomy (19.4). Follow a request in the doorman's logs:

       kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=5

   Recognise your curls: host, path, chosen upstream. The full journey: host port 8081 → node port 80 (extraPortMapping) → controller pod (hostPort) → L7 decision on the Host header → the app's Service (chapter 18: ClusterIP and the coin) → the pod.

   The questions for answers.md: (a) L4 versus L7: what does a Service see and what does the Ingress see? Why is host-based routing impossible at layer 4? (b) the step 2 experiment: why does Kubernetes accept objects nobody realises, and what do Ingress-without-controller and chapter 10's controllers have in common? (think: objects = wishes, controllers = executors — the pattern that makes the system extensible); (c) the full anatomy: list the stations of the journey from your curl to app-uno's pod, noting at each hop who decides (portmapping, hostPort, nginx, ClusterIP...).

6. Tear the building down:

       kind delete cluster --name book-labs-ingress

## Definition of "done"

- [ ] With the rules applied but no controller: curl refused and ADDRESS empty.
- [ ] After the installation: uno.labs.local → app-uno, due.labs.local → app-due, unknown host → 404.
- [ ] You recognised your requests in the controller's logs.
- [ ] answers.md answers the three questions.
- [ ] The book-labs-ingress cluster has been deleted.
