# Chapter 20 — Answers

## The completed TODOs

**TODO 1 (20.2) — keep db alive:** under the db service,

    command: sleep 3600

**TODO 2 (20.2) — keep web alive:** under the web service,

    command: sleep 3600

**TODO 3 (20.3) — web depends on db:** under the web service,

    depends_on:
      - db

The complete compose.yaml:

    services:
      db:
        image: busybox
        command: sleep 3600
      web:
        image: busybox
        command: sleep 3600
        depends_on:
          - db

## Reflection questions

**a. Why service names and never IPs, and what about two projects with a "db"?**

Compose creates one network per project and attaches every service to it, with the
same embedded DNS as a custom bridge (chapter 17): inside the project, "db" resolves
to whatever address the db container currently has. IPs change on every recreation;
the service name does not — so you write the name and never chase an address. Two
different Compose projects each get their own network, and the name "db" is scoped to
that network: project A's web resolves A's db, project B's web resolves B's db, and the
two do not collide or see each other. The name is meaningful only within the app it
belongs to, which is exactly why you can run the same compose file many times, isolated,
without renaming anything.

**b. Why does "started" not mean "ready"?**

depends_on with its default condition (service_started) only guarantees ordering: it
starts db's container before web's and waits for the container process to exist. But a
database process starting is not the same as the database being ready to accept
connections — it may still be loading, replaying logs, opening its socket. So web can
start, try to connect immediately, and fail, even though depends_on "worked". The
distinction matters because real apps must wait for readiness, not just for a process
to exist. The fix is a healthcheck (chapter 21): db declares how to tell it is truly
ready, and web depends_on db with condition: service_healthy, so Compose waits for the
check to pass before starting web.

**c. Why is the declarative model the bridge to Kubernetes?**

A shell script says "do this, then this, then this" — imperative, order-sensitive,
fragile if a step half-fails. A compose file says "here are the services, the network,
the dependencies; make it so" — declarative. You describe the desired state and one
command (up) reconciles reality to it, another (down) removes it. Kubernetes takes this
to its conclusion: you submit manifests describing the desired state, and a controller
loop continuously works to make the cluster match — restarting, rescheduling, scaling
to keep the declared shape. Learning to think in a compose file — state, not steps — is
learning the mindset the Kubernetes book builds on.
