# Chapter 21 — The all-clear signal

**Level:** Advanced

In chapter 20 you started web after db with depends_on. But "started" is not "ready":
a database container can be up while the database inside is still loading, and web
connecting at that instant finds the door closed. depends_on on its own waits for the
container to exist, not for the service to be ready to accept traffic. You need an
all-clear signal. In Docker that signal is the healthcheck: the service declares how
you can tell it is truly ready, and whoever depends on it can wait for that all-clear
instead of guessing with a sleep. In this lab you give db a healthcheck that turns
green only after a delay, and make web wait until db is healthy — not just started.

## Objectives

- Tell "started" from "ready" (started vs healthy) (21.1).
- Declare a healthcheck on a service: how Docker knows it is ready (21.2).
- Make web depend on db with condition: service_healthy — wait for readiness (21.3).
- See that the startup order follows readiness, not an arbitrary time (21.4).

## Prerequisites

- A Linux with Docker Engine running and the Docker Compose plugin (see SETUP.md).
  Your user must be able to use Docker.
- Chapter 20 (Compose, depends_on): here you make it aware of readiness.

## The scenario

In start/ you will find compose.yaml: db does not signal readiness and has no
healthcheck, and web waits only for db to have started. So the readiness gate does not
bite. You fill three gaps (TODO 1..3). The Compose project has a unique name and is
removed at the end (down); the daemon is not touched nor restarted.

Prepare the environment:

    cd docker/ed1/cap21/start

### Phase 1 — The healthcheck (21.2 — TODO 1)

Open start/compose.yaml and complete **TODO 1**: give db a healthcheck. It is the
command Docker runs at intervals to check whether the service is ready — here, whether
the readiness file exists.

    healthcheck:
      test: ["CMD-SHELL", "test -f /tmp/ready"]
      interval: 1s
      timeout: 2s
      retries: 10
      start_period: 1s

### Phase 2 — Delayed readiness (21.1 — TODO 2)

Complete **TODO 2**: make db signal readiness only after a delay, like a real service
that takes a moment to be ready. The file /tmp/ready appears after a few seconds.

    command: ["sh", "-c", "sleep 4; touch /tmp/ready; sleep 3600"]

### Phase 3 — Waiting for the all-clear (21.3 — TODO 3)

Complete **TODO 3**: make web wait for db to be HEALTHY, not just started. With the
service_healthy condition, Compose does not start web until db's healthcheck passes.

    depends_on:
      db:
        condition: service_healthy

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- db has a healthcheck (TODO 1) and becomes ready only after a delay (TODO 2).
- web waits for db to be healthy with condition: service_healthy (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh brings the application up and checks, point by point:

- **OK 1** — db has a healthcheck and reaches the healthy state.
- **OK 2** — web is running and declares depends_on db with condition service_healthy
  (it waits for readiness, not just startup).
- **OK 3** — the gate bites: docker compose up waited for db to be healthy before
  starting web (the up took the readiness time, not an instant).

## Reflection questions

**a.** depends_on with the default condition (service_started) only waits for the
container to exist. Why is that not enough for a database, and what does a healthcheck
declare instead — what are test, interval, retries and start_period for?

**b.** A service with a healthcheck moves through the states starting → healthy (or
unhealthy). How do Docker and Compose use them, and what happens if the healthcheck
never passes — the retries run out and the service_healthy condition is never met? How
would you see it in docker compose up?

**c.** Healthcheck plus depends_on: condition realises a startup order based on
READINESS, not on time — no more "sleep 10" hoping it is enough. Why is this more
robust, and how does it foreshadow Kubernetes readiness and liveness probes, where the
orchestrator uses the same signal to decide when to send traffic to a pod?

## Cleanup

Nothing to tear down by hand: run.sh closes the project with docker compose down
(removing the containers and app network), with a safety trap. The busybox base image
stays in cache. The daemon is never restarted.

## Where it leads

You can start services in the right order and at the right readiness. It remains to
configure them: a real application has environment variables, .env files and secrets
that must not be written into the compose file in the clear. **Chapter 22** closes
Part 6 with configuration — variables, .env and secrets — before the jump to
hardening. For the Compose reference, see the volume's appendices.
