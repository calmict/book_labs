# Chapter 14 — Three ways to stow

**Level:** Intermediate

In chapter 13 you saw that data must be kept ashore, not in the container's hold.
But "ashore" has three different addresses, and choosing wrong is costly. The volume
is the port warehouse: the daemon manages it, it is portable and made for data. The
bind mount is a dock shared with the host: you mount a folder of your machine inside
the container, and what you write is seen on both sides — handy in development,
delicate with permissions. The tmpfs is the ship's fast locker: it lives in memory,
never touches disk, and empties on arrival. In this lab you use all three and verify
the trait that sets each apart.

## Objectives

- Use a bind mount: a host folder mounted inside, with two-way writes (14.2).
- Use a daemon-managed volume, persistent across containers (14.1).
- Use a tmpfs: an in-memory mount, not persisted and never on disk (14.3).
- Recognise which to choose and why (14.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md), native (a bind mount mounts a
  real host path). Your user must be able to use Docker.
- Chapter 13 (the lifecycle of data): here you see the concrete ways to keep it.

## The scenario

In start/ you will find imontaggi.sh: a script that should contrast the three
mounts, but the three key operations are missing. You fill three gaps (TODO 1..3).
Throwaway containers (--rm), a uniquely named volume and a temporary folder: the
shared daemon is not touched.

Prepare the environment:

    cd docker/ed1/cap14/start

### Phase 1 — The shared dock: bind mount (14.2 — TODO 1)

Open start/imontaggi.sh and complete **TODO 1**: mount a host folder at /mnt and
write a file to it from the container. The bind's trait is two-way visibility: the
file appears on the host, at the path you chose.

    docker run --rm -v "$HOSTDIR:/mnt" busybox sh -c 'echo frombind > /mnt/b.txt'

### Phase 2 — The port warehouse: volume (14.1 — TODO 2)

Complete **TODO 2**: after writing into a named volume, read it back from a new
container. The volume's trait is managed persistence: the data lives in the daemon's
area, not in a host path you chose.

    vol_persist=$(docker run --rm -v "$VOL:/data" busybox sh -c 'cat /data/v.txt 2>/dev/null || echo GONE')

### Phase 3 — The ship's locker: tmpfs (14.3 — TODO 3)

Complete **TODO 3**: mount a tmpfs at /cache, write to it, and report the mount type
read from /proc/mounts. The tmpfs's trait is that it lives in memory: it does not
persist and touches neither disk nor host.

    tmpfs_type=$(docker run --rm --tmpfs /cache busybox sh -c 'echo x > /cache/t.txt; grep -q " /cache tmpfs " /proc/mounts && echo TMPFS || echo other')

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- imontaggi.sh writes through a bind mount onto a host folder (TODO 1).
- It reads back from a new container a file written to a volume (TODO 2).
- It mounts a tmpfs and reports its type (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — bind mount: the file written by the container appears on the host, at
  the mounted path (two-way writes with the host).
- **OK 2** — volume: the file written to the volume is read back by a new container
  (persistence managed by the daemon).
- **OK 3** — tmpfs: the /cache mount is of type tmpfs (in memory), so it is not
  persisted and never on disk.

## Reflection questions

**a.** A bind mount and a volume both persist, but where do the data live and who
decides the path? Why does a bind tie everything to a host folder — with its
permissions and the risk of overwriting what is already at the mount point — while a
volume is portable and daemon-managed (create, back up, remove with docker)?

**b.** A tmpfs lives in memory and disappears when the container stops. Why does this
make it right for temporary or sensitive data (that you do not want left on disk) and
for speed-sensitive scenarios? What happens to its contents when the container stops,
and why does it appear in no volume and not on the host?

**c.** Rule of thumb: in development you mount the code with a bind (live edits), in
production you keep data in a volume, and you use tmpfs for ephemeral cache or
secrets. Why is mounting the code with a bind in production fragile, and how does the
choice connect to the UID/GID permissions on shared volumes of chapter 15?

## Cleanup

Nothing to tear down by hand: the containers are throwaway (--rm), the named volume
is removed by the script (docker volume rm, plus a safety trap), and the bind folder
lives in a temporary directory that run.sh cleans up itself. The tmpfs disappears
with its container. The busybox base image stays in cache. The daemon is never
restarted.

## Where it leads

You know where to put data and with which mount. One detail still trips everyone up
when sharing a volume or a bind: permissions. **Chapter 15** tackles UID and GID on
shared volumes — why a non-root container (chapter 12) sometimes cannot write to a
volume, and how the identifiers line up. For the command reference, see the volume's
appendices.
