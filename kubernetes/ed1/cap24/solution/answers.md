# Chapter 24 — Answers (model solution)

## The mould renders

    kind: ConfigMap
        Greetings from revision one
    kind: Service
    kind: Deployment
      replicas: 1

## The three casts

    revision 1:  replicas 1,  "Greetings from revision one"
    revision 2:  replicas 3,  "Greetings from revision two"  (pods rolled)
    rollback:    replicas 1,  "Greetings from revision one"

    REVISION  STATUS      DESCRIPTION
    1         superseded  Install complete
    2         superseded  Upgrade complete
    3         deployed    Rollback to 1

## The three questions

**a. Chart, template and values (24.2): what does the mould separate from
the settings? {{ .Release.Name }} vs {{ .Values.message }}, values.yaml vs
--set, and what helm template shows that helm install does not.**

The chart separates SHAPE from SETTINGS. The templates are the mould: the
structure of the manifests, written once, with holes where values go.
values.yaml is the settings sheet: the knobs, with their defaults. Pour
one into the other and you get concrete manifests — the same shape, cast
again and again with different numbers, instead of three hand-copied files
that drift apart. The two kinds of hole differ in where they read from:
{{ .Release.Name }} comes from Helm itself (the name you gave the release
on install, so the same chart can be installed many times side by side
under different names), while {{ .Values.message }} comes from your
values — the settings you chose. Those settings can be set in values.yaml
(the committed default) or overridden per-install with --set on the
command line (values.yaml is the baseline, --set wins over it, so you keep
one chart and vary it per environment). helm template renders the mould to
plain YAML and prints it WITHOUT touching the cluster — it is the dry run
that lets you see exactly what would be applied, catch a templating
mistake, or pipe it elsewhere; helm install renders the same thing but
then sends it to the apiserver and records a release.

**b. Release and rollback (24.3): what is a release and a revision, what
does helm rollback do, why does a ConfigMap-only change not restart the
pods (and how does checksum/config fix it), and where does Helm keep the
history?**

A RELEASE is one named installation of a chart into a namespace (our
"greeter"). A REVISION is one version of that release in time: install is
revision 1, each upgrade is a new revision, and — the point that surprises
people — a rollback is ALSO a new revision, not a deletion. Our history
ended with three lines (install, upgrade, rollback-to-1) precisely because
Helm never erases: it stacks. helm rollback N re-applies the exact
manifests that revision N had stored, then records that as the next
revision. Helm keeps every revision's full manifests as SECRETS in the
release namespace — you saw sh.helm.release.v1.greeter.v1, .v2, .v3; that
is the release state and history, which is why rollback can reconstruct an
old cast precisely. The ConfigMap trap: a Deployment only rolls its pods
when its POD TEMPLATE changes. Editing a mounted ConfigMap changes the
ConfigMap object, not the pod template, so the running pods keep the old
content (the projected volume updates lazily, but nothing forces a
restart). The checksum/config annotation puts a sha256 of the ConfigMap
INTO the pod template's annotations: change the config and the hash
changes, so the pod template changes, so the Deployment rolls the pods and
they pick up the new content immediately — which is why our upgrade and
rollback flipped the served message deterministically.

**c. Helm in practice (24.4): what is a chart repository, why is
installing an addon the same helm install with someone else's mould, and
how often will you write a chart versus install a ready-made one?**

A chart repository is an indexed collection of packaged charts served over
HTTP; helm repo add gives it a name, helm install then pulls a chart from
it exactly the way we installed ours from a local directory. That is the
whole point of Helm as a PACKAGE MANAGER: installing metrics-server,
ingress-nginx, cert-manager or Prometheus is the same helm install /
upgrade / rollback dance you just did, only the mould was written and
maintained by someone else and its knobs (values) are documented for you
to override. In a real cluster the ratio is lopsided: you install
ready-made charts constantly (every addon, every off-the-shelf component)
and you write your own charts occasionally — for your own applications.
Building greeter by hand here was to understand the mould from the inside;
most days you will be pouring settings into moulds other people cast, and
knowing helm template, --set, history and rollback is what makes that
safe.
