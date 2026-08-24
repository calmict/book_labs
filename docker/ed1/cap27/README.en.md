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
- Back up a volume and restore it into a new volume with a utility container (27.3).
- Exercise the tag, push, removal and pull cycle with a local private registry (27.3).
- Frame the horizons: the limits of a single host and the bridge to orchestration (27.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use Docker.
- The whole volume: here you tidy up what the previous chapters created.

## The scenario

In start/ you will find maintenance.sh: a script that creates a stopped container and an unused
volume, both labelled as yours, and should reclaim them safely, back up and restore a
volume, and exercise a local registry — but five operations are missing. You fill five
gaps (TODO 1..5). All the resources are labelled and removed
by scope only: the shared daemon and other people's resources are not touched.

Prepare the environment:

    cd docker/ed1/cap27/start

### Phase 1 — Reclaim stopped containers, by scope (27.2 — TODO 1)

Open start/maintenance.sh and complete **TODO 1**: reclaim the stopped containers that belong
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

### Phase 4 — Back up and restore a volume (27.3 — TODO 4)

Complete **TODO 4**: write known content into a volume, then use a throwaway container
to mount it read-only and create an archive in the working directory. A second container
restores the archive into a new volume. Finally compare the restored text with the
original: equality is deterministic.

    docker run --rm -v "$BACKUP_VOL:/data:ro" -v "$OUT:/backup" busybox tar czf "/backup/$(basename "$ARCHIVE")" -C /data .
    docker run --rm -v "$RESTORE_VOL:/data" -v "$OUT:/backup:ro" busybox tar xzf "/backup/$(basename "$ARCHIVE")" -C /data

### Phase 5 — A local private registry (27.3 — TODO 5)

Complete **TODO 5**: start registry:2, publishing its port only on 127.0.0.1, and let
Docker choose a free host port. Retag busybox with a cap27 name for that registry, push
it, remove only the tag you just created, and pull it. The digest read immediately after
the push must match the final pull digest. Do not remove busybox.

One honest note about the pull: busybox's layers stay in the local cache, because the
original tag still uses them. What the pull proves is not a fresh download, but that the
registry keeps the manifest and hands it back with the same digest after the local tag
is gone.

Docker permits an HTTP registry on loopback without configuring insecure-registries.
A registry reached through a real IP address does not get this exception: it needs TLS
or explicit daemon configuration, which this lab does not change.

    docker run -d --name "$REGISTRY" --label "owner=$LABEL" -p 127.0.0.1::5000 registry:2 >/dev/null
    docker tag busybox "$REGISTRY_TAG"
    docker push "$REGISTRY_TAG"
    docker image rm "$REGISTRY_TAG"
    docker pull "$REGISTRY_TAG"

Once the five TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- maintenance.sh reclaims its own stopped containers with a label-filtered prune (TODO 1).
- It removes its own named volume (TODO 2).
- It recounts and confirms nothing of its own remains (TODO 3).
- It restores the known content from the archive into a new volume (TODO 4).
- It completes a tag round trip through the local registry (TODO 5).
- run.sh prints OK 1..5 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — before the cleanup there is a stopped container and a volume labelled as
  yours (the orphans to reclaim).
- **OK 2** — after the label-filtered prune, your stopped container is gone.
- **OK 3** — after the removal by name, your volume is gone: complete reclaim, scoped.
- **OK 4** — the restored volume contains exactly the known text written before the
  backup.
- **OK 5** — after the push, tag removal and pull from the local registry, the tag is
  present again with the same digest read immediately after the push.

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

**d.** Why does the container that creates the archive mount the source volume read-only,
and why does the restore target a new volume instead of overwriting the original? Which
checks would you add to a real backup procedure?

**e.** Why is the lab registry bound only to 127.0.0.1, and what changes when it is
exposed on a real IP address? In production, why are TLS, authentication and an image
retention policy part of the service rather than optional details?

## Cleanup

The script removes its own resources by scope, with a safety trap that cleans up
regardless: the three cap27 volumes, the registry container, the registry tag and the
backup archive. Utility containers are throwaway. The original busybox image stays in
cache. No one else's resources are touched, the daemon is never restarted, and the
loopback port is released.

## Where it leads

With this chapter the Docker manual closes: from the masked process of chapter 1 to the
ship in production, you crossed the illusion of isolation, the engine, images, persistence,
networks, local orchestration and hardening. The horizon is orchestration across many hosts
— and the volume's appendices carry you beyond: in particular appendix E, "From the single
host to the orchestrator", is the explicit bridge toward the Kubernetes book. Fair winds.
