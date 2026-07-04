# Chapter 24 — The Mould and the Casts (Helm, the package manager)

> Exercise for **Chapter 24 — Helm, the Kubernetes package manager** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Cloud Architect

## Objectives

By the end of this lab you will be able to:

- feel the problem Helm solves: keeping dozens of near-identical manifests by hand, differing by two lines — the copy-paste cramp;
- build a local chart: one mould (the templates) plus a settings sheet (values), and watch the same mould cast different manifests as the values change;
- manage releases as numbered casts: install, upgrade with new values, read the history and roll back — and understand why a config-only change does not restart the pods.

## Prerequisites

- Chapter 15 completed (rollout and rollback by hand: here Helm does them, versioned) and familiarity with Deployment/Service/ConfigMap from earlier chapters.
- The book-labs cluster running and the helm binary installed (helm version). Everything is local-first: you build your own chart, no external repository required.
- In start/: plain.yaml (the "before", hand-written manifests) and greeter/ (the chart skeleton, with TODOs in the templates).

## Instructions

1. The copy-paste cramp. Open start/plain.yaml: a ConfigMap, a Deployment and a Service, every value hand-written. Imagine keeping three copies — dev, staging, prod — identical except for the replica count and one message. Every change must be repeated by hand on all of them: that is the problem Helm solves.

2. Build the mould. In start/greeter/ you have Chart.yaml and values.yaml ready, and three templates with TODOs. Complete the templates by replacing the fixed values with Helm expressions: the release name ({{ .Release.Name }}), the replica count ({{ .Values.replicaCount }}) and the message ({{ .Values.message }}). Then see what the mould would cast, without installing anything:

       helm lint greeter
       helm template greeter greeter

   helm template renders the templates into real manifests, with the values from values.yaml in place of the expressions. No copy-paste: a single mould.

3. The first cast. Install the chart as a release named greeter, in its own namespace:

       helm install greeter greeter -n helmlab --create-namespace --wait
       helm list -n helmlab
       kubectl -n helmlab get deploy,svc,cm

   This is revision 1. Read what the cast declares and what it actually serves:

       kubectl -n helmlab get cm greeter-page -o jsonpath='{.data.index\.html}'
       kubectl -n helmlab exec deploy/greeter -- wget -qO- http://localhost:8080

   One replica, "Greetings from revision one".

4. Recast with new settings. Change two values on the fly and upgrade the release:

       helm upgrade greeter greeter -n helmlab --set replicaCount=3 --set message="Greetings from revision two" --wait
       helm history -n helmlab greeter

   Revision 2: three replicas and the new message. Note an important detail: the message changed because the chart carries a checksum/config annotation on the pod template — a fingerprint of the ConfigMap. Without it, changing only the ConfigMap would NOT restart the pods, and they would keep serving the old content.

5. Back to the previous cast. Roll back to revision 1:

       helm rollback greeter 1 -n helmlab --wait
       helm history -n helmlab greeter
       kubectl -n helmlab get cm greeter-page -o jsonpath='{.data.index\.html}'

   The history now has three lines (install, upgrade, rollback-to-1) and the ConfigMap is back to "revision one": Helm does not erase, it stacks. Every cast stays in the history, and rolling back is itself a new revision.

6. Tear the release and namespace down:

       helm uninstall greeter -n helmlab
       kubectl delete namespace helmlab

## The questions for answers.md

- (a) Chart, template and values (24.2). What does the mould (the templates) separate from the settings (values)? Explain the difference between {{ .Release.Name }} and {{ .Values.message }}, between setting a value in values.yaml and passing it with --set, and what helm template shows you that helm install does not.
- (b) Release and rollback (24.3). What is a release and what is a revision? What does helm rollback actually do (re-apply the manifests of a previous revision)? And the trap you saw: why does changing only a ConfigMap not restart the pods, and how does the checksum/config annotation fix it? Where does Helm keep the release history: take a look at the Secrets in the namespace.
- (c) Helm in practice (24.4). What is a chart repository (helm repo add) and why is installing an addon such as ingress-nginx or metrics-server the same helm install you just ran, but with someone else's mould? Here you built your own chart (local-first); in production, how often will you write a mould versus install a ready-made one?

## Definition of "done"

- [ ] Templates completed: helm lint clean and helm template renders manifests with your values.
- [ ] Revision 1 installed: one replica, "revision one" served.
- [ ] Revision 2 after the upgrade: three replicas and "revision two" (the pods were rolled).
- [ ] Rollback: the history has three lines and the ConfigMap is back to "revision one".
- [ ] answers.md answers the three questions; release and namespace removed.
