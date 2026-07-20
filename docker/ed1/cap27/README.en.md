# Chapter 27 — Clean the hold, watch the sea

**Level:** Cloud Architect

Every voyage leaves residue. Containers stopped and never removed, old images no one uses
any more, volumes orphaned when their container vanished: over time the hold fills up and
the disk runs out. Day-2 — the life after the first deploy — is made of this too: knowing
what takes up space and reclaiming it, but with judgement. Because on a shared machine a
docker system prune given lightly deletes other people's work as well. In this lab you
clean up safely — only the resources that carry your own label — and then you look up:
where Docker on a single host ends, and where the horizon of orchestration begins.

## Objectives

- Recognise orphans: stopped containers, unused volumes taking up space (27.1).
- Reclaim space safely, scoped (labels, names), never a global prune on a shared host
  (27.2).
- Verify that only your resources were removed (27.2).
- Frame the horizons: the limits of a single host and the bridge to orchestration (27.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use Docker.
- The whole volume: here you tidy up what the previous chapters created.

## The scenario

In start/ you will find imaint.sh: a script that creates a stopped container and an unused
volume, both labelled as yours, and should reclaim them safely — but the three operations
are missing. You fill three gaps (TODO 1..3). All the resources are labelled and removed
by scope only: the shared daemon and other people's resources are not touched.

Prepare the environment:

    cd docker/ed1/cap27/start

### Phase 1 — Reclaim stopped containers, by scope (27.2 — TODO 1)

Open start/imaint.sh and complete **TODO 1**: reclaim the stopped containers that belong
to you, filtering by your label. It is a scoped prune: it touches only yours, never other
people's.

    docker container prune -f --filter "label=owner=$LABEL" >/dev/null

### Phase 2 — Reclaim the volume, by name (27.2 — TODO 2)

Complete **TODO 2**: remove the named volume you created. Explicit and targeted — no
generic volume prune that might catch other people's too.

    docker volume rm "$VOL" >/dev/null

### Phase 3 — Verify (27.2 — TODO 3)

Complete **TODO 3**: recount your resources after the cleanup. None of yours should remain
— and nothing else was touched.

    con_after=$(docker ps -aq --filter "label=owner=$LABEL" | grep -c . || true)
    vol_after=$(docker volume ls -q --filter "label=owner=$LABEL" | grep -c . || true)

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- imaint.sh reclaims its own stopped containers with a label-filtered prune (TODO 1).
- It removes its own named volume (TODO 2).
- It recounts and confirms nothing of its own remains (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — before the cleanup there is a stopped container and a volume labelled as
  yours (the orphans to reclaim).
- **OK 2** — after the label-filtered prune, your stopped container is gone.
- **OK 3** — after the removal by name, your volume is gone: complete reclaim, scoped.

## Reflection questions

**a.** Orphans arise everywhere: containers stopped without --rm, "dangling" images left
after a rebuild, volumes no one deletes (chapter 13). Why is docker system prune given
without thinking dangerous on a shared machine, and how does working by scope make it safe
— filters by label, removals by name, never "everything"?

**b.** docker system df shows where space goes: images, containers' writable layers,
volumes, build cache. What consumes the most in a real environment, and why is managing
space (including the log rotation of chapter 25) a routine rather than an emergency?

**c.** On a single host Docker reaches a limit: if the machine falls, the containers fall
with it; scaling means starting copies by hand; there is no self-healing. Why is this the
boundary beyond which you need an orchestrator, and how is everything you learned — images,
networks, volumes, Compose, healthchecks, security — exactly the vocabulary Kubernetes
thinks in? It is the bridge of the Kubernetes book.

## Cleanup

The script removes its own resources by scope (a label-filtered prune and a removal by
name), with a safety trap that cleans up regardless. No one else's resources are touched,
the daemon is never restarted.

## Where it leads

With this chapter the Docker manual closes: from the masked process of chapter 1 to the
ship in production, you crossed the illusion of isolation, the engine, images, persistence,
networks, local orchestration and hardening. The horizon is orchestration across many hosts
— and the volume's appendices carry you beyond: in particular appendix E, "From the single
host to the orchestrator", is the explicit bridge toward the Kubernetes book. Fair winds.
