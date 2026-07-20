# Chapter 14 — Answers

## The completed TODOs

**TODO 1 (14.2) — bind mount: the write lands on the host:**

    docker run --rm -v "$HOSTDIR:/mnt" busybox sh -c 'echo frombind > /mnt/b.txt'

**TODO 2 (14.1) — volume: read it back from a fresh container:**

    vol_persist=$(docker run --rm -v "$VOL:/data" busybox sh -c 'cat /data/v.txt 2>/dev/null || echo GONE')

**TODO 3 (14.3) — tmpfs: mount in memory and report the type:**

    tmpfs_type=$(docker run --rm --tmpfs /cache busybox sh -c 'echo x > /cache/t.txt; grep -q " /cache tmpfs " /proc/mounts && echo TMPFS || echo other')

## Reflection questions

**a. Bind mount vs volume: where do the data live, and who decides the path?**

A bind mount maps an exact host path into the container: the two sides share the
same files, so a write inside is a write on the host, and vice versa. That is its
power (edit code on the host, see it live in the container) and its danger — the data
carries the host's ownership and permissions, the path must exist and be the same on
every machine, and mounting over a non-empty directory hides what was there. A volume
is different: you name it and the daemon decides where it physically lives (under its
own storage area). You never point at a host path, so it is portable across machines,
and it is managed with docker (create, inspect, back up, prune). Rule of thumb: bind
when you deliberately want to share a specific host location; volume when you just
want durable, portable data and do not care where it sits.

**b. Why is a tmpfs in memory, and what happens on stop?**

A tmpfs mount is backed by RAM (and swap), not by a disk file — /proc/mounts shows
its type as tmpfs. Nothing is written to the image's layers, to a volume, or to the
host: it exists only for the life of the container. When the container stops, the
memory is freed and the contents vanish, leaving no trace on disk. That makes it
ideal for two cases: scratch data you want fast and do not need to keep (a build
cache, a scratch dir), and sensitive data — decrypted secrets, tokens — that you
specifically do not want persisted to disk where it could be recovered later. It
appears in no volume and not on the host precisely because it was never on disk at
all.

**c. Which to choose, and why is a bind fragile in production?**

Development: bind-mount the source so your edits appear in the container instantly.
Production: keep state in a volume, portable and backed up with the platform, not
tied to a host layout. Ephemeral needs: tmpfs for caches or short-lived secrets.
Bind mounts are fragile in production because they hard-code a host path that may not
exist, or may differ, on the real server; they drag the host's file ownership into
the container (so a non-root container may be unable to write); and they couple the
app to one machine's filesystem. That ownership problem is exactly chapter 15: a
non-root container (chapter 12) writing to a shared volume or bind must have UID/GID
that line up with the files, or its writes are denied.
