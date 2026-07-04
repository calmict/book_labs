# Chapter 24 — Answers

## The mould renders

    # paste here a few lines of helm template output (kind:, replicas:, the message)

## The three casts

    # paste here: revision 1 (1 replica, "revision one"),
    # revision 2 (3 replicas, "revision two"), and the rollback
    # (helm history with three lines, ConfigMap back to "revision one")

## The three questions

**a. Chart, template and values (24.2): what does the mould separate from
the settings? {{ .Release.Name }} vs {{ .Values.message }}, values.yaml vs
--set, and what helm template shows that helm install does not.**

_(your answer)_

**b. Release and rollback (24.3): what is a release and a revision, what
does helm rollback do, why does a ConfigMap-only change not restart the
pods (and how does checksum/config fix it), and where does Helm keep the
history?**

_(your answer)_

**c. Helm in practice (24.4): what is a chart repository, why is
installing an addon the same helm install with someone else's mould, and
how often will you write a chart versus install a ready-made one?**

_(your answer)_
