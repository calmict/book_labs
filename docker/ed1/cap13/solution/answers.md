# Chapter 13 — Answers

## The completed TODOs

**TODO 1 (13.3) — create the named volume:**

    docker volume create "$VOL" >/dev/null

**TODO 2 (13.3) — write a file into the volume:**

    docker run --rm -v "$VOL:/data" busybox sh -c 'echo hi > /data/persisted.txt'

**TODO 3 (13.3) — read it back from a fresh container, and confirm the volume:**

    persisted=$(docker run --rm -v "$VOL:/data" busybox sh -c 'cat /data/persisted.txt 2>/dev/null || echo GONE')
    vol_exists=$(docker volume ls -q | grep -cx "$VOL" || true)

## Reflection questions

**a. Why is the writable layer not the place to keep data?**

An image is a stack of read-only layers (chapter 8); when a container starts, Docker
adds one thin writable layer on top, private to that container, where every change
it makes is stored (copy-on-write). That layer belongs to the container, not to the
image: docker rm deletes the container and its writable layer with it. So anything a
container writes outside a volume — a database's files, an upload, a log — lives only
as long as that one container. Recreate it (to change the image, to move hosts) and
the layer, and everything in it, is gone. "Ephemeral" is not a bug; it is what the
writable layer is for: scratch space, not storage.

**b. Why does a daemon-managed volume let you recreate the container without losing
data?**

A volume is not part of any container's layer stack — it is a separate storage area
the daemon manages and mounts into a container at a path. Because it lives outside
the container, removing or replacing the container leaves the volume untouched: the
new container mounts the same volume and finds the same data. That is exactly how you
upgrade a database's image without losing its files. And because a volume is a shared
mount rather than a private layer, two containers can mount the same volume and see
the same files, whereas their writable layers are private and invisible to each other
by construction.

**c. If the volume outlives the container, who removes it?**

You do — explicitly, with docker volume rm (or docker volume prune for unused ones).
A volume has its own lifecycle, independent of containers: it is created on demand
and stays until removed, even when nothing uses it. The upside is durability; the
cost is that volumes accumulate. "Orphan" volumes left by removed containers quietly
consume disk, and — more seriously — a volume may hold sensitive data (database
contents, secrets a container wrote) that survives long after the container is gone,
until someone deliberately deletes it. Persistence is a responsibility as much as a
feature.
