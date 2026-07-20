# Chapter 21 — Answers

## The completed TODOs

**TODO 1 (21.2) — db's healthcheck:** under the db service,

    healthcheck:
      test: ["CMD-SHELL", "test -f /tmp/ready"]
      interval: 1s
      timeout: 2s
      retries: 10
      start_period: 1s

**TODO 2 (21.1) — db signals readiness only after a delay:**

    command: ["sh", "-c", "sleep 4; touch /tmp/ready; sleep 3600"]

**TODO 3 (21.3) — web waits for db to be healthy:** under the web service,

    depends_on:
      db:
        condition: service_healthy

## Reflection questions

**a. Why is service_started not enough, and what does a healthcheck declare?**

depends_on with the default condition (service_started) only guarantees that db's
container process has been started before web's — it says nothing about whether the
database inside is ready. A real database spends seconds after its process starts
loading data, replaying logs, opening its listening socket; connect during that window
and you get "connection refused", even though depends_on "worked". A healthcheck fills
the gap: test is the command Docker runs inside the container to ask "are you ready?"
(here, does the readiness file exist); interval is how often; timeout is how long each
probe may take; retries is how many failures before the service is declared unhealthy;
start_period is a grace window at boot during which failures do not count. Together
they turn "the process exists" into "the service answers".

**b. The health states, and what if the check never passes.**

A service with a healthcheck starts in state "starting"; once test succeeds it becomes
"healthy", and if it fails enough times (retries) it becomes "unhealthy". Docker
records the status (visible in docker ps and docker inspect), and Compose uses it: a
dependent with condition: service_healthy is held until the dependency is healthy. If
db's check never passes — a bug, a wrong test, a service that truly cannot start — the
retries run out, service_healthy is never satisfied, and Compose does not start web;
docker compose up reports the dependency failing to become healthy and gives up rather
than launching a web that would only crash against a db that is not there.

**c. Why readiness beats time, and the bridge to Kubernetes.**

The old workaround was "sleep 10 and hope the db is up by then" — arbitrary, fragile,
too short on a slow machine and wastefully long on a fast one. A healthcheck plus
condition: service_healthy replaces the guess with a fact: web starts exactly when db
reports ready, no sooner and no later, on any machine. That is more robust because it
follows the real state, not the clock. Kubernetes generalises the very same idea with
readiness and liveness probes: a readiness probe tells the cluster when a pod may
receive traffic (the same "is it ready?" question), a liveness probe tells it when to
restart a pod that has gone bad. The healthcheck you wrote here is the single-host
seed of that cluster-wide mechanism.
