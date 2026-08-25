# Chapter 13 — What stays ashore

**Level:** Foundational

A container is a ship: it sets sail, makes its voyage, and sooner or later is
scrapped. Everything you write in its hold — the writable layer you met in chapter
8 — goes down with it when you remove it. It is the surprise that catches everyone
the first time: you run a database, populate it, remove the container to upgrade it,
and the data is gone. Part 4 answers this question — if the container is ephemeral,
where do the data live? — and the answer is: ashore. In this lab you see first-hand
that the container's layer dies with it, and that a volume, kept by the daemon
ashore, outlives the ship.

## Objectives

- See that the container's writable layer is ephemeral: a new container does not see
  the files a previous one wrote (13.1, 13.2).
- Create a named volume and write into it (13.3).
- Verify the volume survives the removal of the container that wrote it (13.3).
- Understand that a volume is a first-class object with its own lifecycle,
  independent of any container (13.3).
- Distinguish stopping, which preserves the writable layer, from removing the
  container, which deletes it (13.2).
- Observe the volume count reported by docker system df in structured form, without
  depending on machine-specific disk usage (13.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 8 (layers): here you discover the writable top layer is not a place to
  keep data.

## The scenario

In start/ you will find persistence.sh: a script that should contrast two fates — a file
written to the container's layer and one written to a volume — but the volume and
lifecycle checks are not done yet. You fill five gaps (TODO 1..5). Containers and
the volume have unique names and are removed at the end: the shared daemon is not
touched.

Prepare the environment:

    cd docker/ed1/cap13/start

### Phase 1 — The container's layer is ephemeral (13.1, 13.2)

The script starts a container, writes a file in its filesystem and removes it. Then
a new container, from the same image, looks for that file: it is not there. The
writable layer is private to the container and thrown away when the container is
gone — not a place to keep anything that must last.

### Phase 2 — Creating a volume (13.3 — TODO 1)

Open start/persistence.sh and complete **TODO 1**: create a named volume. It is an area
managed by the daemon, outside any container's layer.

    docker volume create "$VOL" >/dev/null

### Phase 3 — Writing into the volume (13.3 — TODO 2)

Complete **TODO 2**: start a container that mounts the volume at /data and writes a
file there. Then the container is removed (--rm), but the file is in the volume, not
in the container's layer.

    docker run --rm -v "$VOL:/data" busybox sh -c 'echo hi > /data/persisted.txt'

### Phase 4 — Reading back after removal (13.3 — TODO 3)

Complete **TODO 3**: a new container mounts the same volume and reads the file back.
If it persists, the container's layer had nothing to do with it: the data lives in
the volume.

    persisted=$(docker run --rm -v "$VOL:/data" busybox sh -c 'cat /data/persisted.txt 2>/dev/null || echo GONE')

### Phase 5 — Stop and start are not rm (13.2 — TODO 4)

Complete **TODO 4**: start a container that stays alive, write once to its layer
with docker exec, then stop and restart it. Read the data with docker exec: it must
still be there. Then remove the container and recreate it from the same image: the
data must not exist in the new layer. The main command is sleep and does not rewrite
the file when the container restarts.

    docker run -d --name "$LIFE_CONTAINER" busybox sleep 300 >/dev/null
    docker exec "$LIFE_CONTAINER" sh -c 'echo hi > /lifecycle.txt'
    docker stop "$LIFE_CONTAINER" >/dev/null
    docker start "$LIFE_CONTAINER" >/dev/null
    after_restart=$(docker exec "$LIFE_CONTAINER" cat /lifecycle.txt)
    docker rm -f "$LIFE_CONTAINER" >/dev/null
    docker run -d --name "$LIFE_CONTAINER" busybox sleep 300 >/dev/null
    after_recreate=$(docker exec "$LIFE_CONTAINER" sh -c 'cat /lifecycle.txt 2>/dev/null || echo GONE')

### Phase 6 — Where disk usage grows (13.4 — TODO 5)

Complete **TODO 5**: query docker system df with a structured format and extract the
count from the Local Volumes row. The number depends on other volumes on the
machine: the test compares neither bytes nor thresholds, but only verifies that the
count is readable and includes at least the volume the script just created.

    volume_df_count=$(docker system df --format '{{.Type}}|{{.TotalCount}}' | awk -F'|' '$1 == "Local Volumes" {print $2}')

Once the five TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- persistence.sh creates the named volume (TODO 1).
- It writes a file into the volume from a throwaway container (TODO 2).
- It reads the file back from a new container mounting the same volume (TODO 3).
- It proves stop and start preserve data written once to the layer, while removing
  and recreating the container deletes it (TODO 4).
- It reads the volume count from structured docker system df output (TODO 5).
- run.sh prints OK 1..5 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — the container's layer is ephemeral: the file written in the container's
  filesystem is not visible to a new container (result GONE).
- **OK 2** — the volume persists: the file written to the volume is read back by a
  new container, after the first was removed (result hi).
- **OK 3** — the volume has its own lifecycle: it still exists, listed by the daemon,
  even with no container using it.
- **OK 4** — the same data in the writable layer survives stop and start; the
  countercheck shows it is absent after rm and container recreation.
- **OK 5** — docker system df exposes a Local Volumes row with a readable numeric
  count while the exercise volume exists.

## Reflection questions

**a.** Why is the writable layer on top of the image (chapter 8) not the place to
keep data? What exactly happens to that layer when you docker rm, and why does this
make "ephemeral" everything a container writes outside a volume?

**b.** A volume is managed by the daemon and lives independently of containers: why
does this let you upgrade the image or recreate the container without losing data?
And why can two containers mount the same volume, while they do not share each
other's writable layers?

**c.** If the volume survives the container's removal, who removes it? What does this
imply for disk space (orphan volumes) and for sensitive data left in a volume nobody
deletes?

**d.** Why do stop and start preserve data in the writable layer, while rm and
recreation from the same image make it disappear? What does docker system df
measure, and why is a fixed byte threshold incorrect across different machines?

## Cleanup

Nothing to tear down by hand: throwaway containers remove themselves with --rm;
the stop/start test container and the named volume are removed by targeted commands
in the script, plus a safety trap, at the end. The busybox base image stays in cache
(shared). The daemon is never restarted.

## Where it leads

You saw the difference between what dies with the container and what stays ashore.
**Chapter 14** goes into the concrete ways to keep data ashore and share it with the
host: bind mounts, volumes and tmpfs — when to use each, and what changes between
data managed by the daemon and a host folder mounted inside. For the command
reference, see the volume's appendices.
