# Chapter 15 — The number on the badge

**Level:** Advanced

You learned to run as a non-root user (chapter 12) and to mount shared data (chapter
14). Put the two together and you trip over the classic: the non-root container tries
to write to the volume and is told "permission denied". The reason is that at a
mount's boundary permissions are read not by name but by number: what counts is the
UID, a numeric badge. If the container's number does not own the mounted files, it
does not write — full stop. In this lab you reproduce the mismatch, fix it by running
the container with the right UID, and verify that the number crosses the boundary
unchanged: UID N inside is UID N on the host. Then you reproduce the everyday
nuisance — the container left running as root that fills your folder with files you
can no longer touch — and cure it two more ways: with USER declared in the image,
and with an entrypoint that fixes the ownership and hands the place over to the
unprivileged user.

## Objectives

- See that on a shared mount permissions apply by numeric UID/GID, not by user name
  (15.1).
- Reproduce the problem: a container with a UID that does not own the folder cannot
  write (15.2).
- Fix it by running the container with the UID that owns the files (--user) (15.3).
- Verify the UID is not translated: the file the container creates is owned by the
  same UID on the host (15.1).
- Reproduce the root-owned files problem: a container left as root writes to the
  mount and leaves behind a tree you cannot remove from the host (15.1).
- Cure it two different ways: the identity declared in the image with USER (15.2),
  and the entrypoint that fixes the ownership as root and then hands over with exec
  (15.3).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md), native (a bind mount uses the
  host's real permissions). Your user must be able to use Docker.
- Chapter 12 (non-root containers) and chapter 14 (bind mounts): here you make them
  collide with permissions.

## The scenario

In start/ you will find ipermessi.sh: a script that prepares a host folder you own,
mounts it in a container and should show the mismatch and its cures — but the key
proofs are missing. You fill six gaps (TODO 1..6).

Next to it there are two ready-made Dockerfiles, Dockerfile.user and
Dockerfile.entrypoint, and the script fixperms.sh the second one uses as its
entrypoint: they are the material for phases 5 and 6, with no TODOs inside.
Throwaway containers and images and a temporary folder: no privileges on the host,
the daemon is not touched.

Prepare the environment:

    cd docker/ed1/cap15/start

### Phase 1 — The problem: wrong badge (15.2 — TODO 1)

Open start/ipermessi.sh and complete **TODO 1**: the host folder is owned by your
UID. Run a container with a different (non-root) UID that tries to write to the
mount: it is refused, because that number does not own the folder and is only
"other", with no write permission.

    mismatch=$(docker run --rm --user "$OTHER_UID" -v "$HOSTDIR:/data" busybox sh -c 'touch /data/x 2>/dev/null && echo WROTE || echo DENIED')

### Phase 2 — The cure: right badge (15.3 — TODO 2)

Complete **TODO 2**: repeat the same write, but with the container running as the UID
that owns the folder. Same mount, same command: only the number changes, and now the
write goes through.

    match=$(docker run --rm --user "$HOST_UID" -v "$HOSTDIR:/data" busybox sh -c 'touch /data/ok 2>/dev/null && echo WROTE || echo DENIED')

### Phase 3 — The number crosses the boundary (15.4 — TODO 3)

Complete **TODO 3**: look, from the host, who owns the file the container just
created. There is no translation: the container's UID is the same UID on the host.

    owner_uid=$(stat -c '%u' "$HOSTDIR/ok" 2>/dev/null || echo NONE)

### Phase 4 — The everyday nuisance: root-owned files (15.1 — TODO 4)

Complete **TODO 4**: let a container run as root — that is, the way it runs by
default — and create a folder with a file inside it on the shared mount. Then look
from the host at who owns them, and try to remove them.

    ROOTDIR="$HOSTDIR/state"
    docker run --rm -v "$HOSTDIR:/data" busybox sh -c 'mkdir -p /data/state && echo seed > /data/state/f'
    root_owner=$(stat -c '%u' "$ROOTDIR/f")
    rm -rf "$ROOTDIR" 2>/dev/null && host_cleanup=REMOVED || host_cleanup=DENIED

They belong to UID 0, and your user cannot remove them: deleting a file needs write
permission on the folder that holds it, and that folder was created by root. This is
why, after a development session in containers, you end up with folders that only
sudo can clear.

### Phase 5 — Cure: the identity in the image (15.2 — TODO 5)

Complete **TODO 5**: build Dockerfile.user passing your own UID as a build argument,
and write with that image. No flag is needed at run time: the identity is declared
in the image with USER, and every container born from it starts with the right
number already.

    docker build -q -t "$IMG_USER" --build-arg "APP_UID=$HOST_UID" -f "$HERE/Dockerfile.user" "$HERE" >/dev/null
    user_write=$(docker run --rm -v "$HOSTDIR:/data" "$IMG_USER" sh -c 'touch /data/by-user 2>/dev/null && echo WROTE || echo DENIED')
    user_owner=$(stat -c '%u' "$HOSTDIR/by-user" 2>/dev/null || echo NONE)

### Phase 6 — Cure: fix it, then hand over (15.3 — TODO 6)

Complete **TODO 6**: build Dockerfile.entrypoint and run it on the tree root left
locked for you in phase 4. The fixperms.sh script starts as root — it needs to, to
chown — fixes the ownership, and then hands the place over to the unprivileged user
with exec: from that moment the process is no longer root.

    docker build -q -t "$IMG_ENTRY" -f "$HERE/Dockerfile.entrypoint" "$HERE" >/dev/null
    entry_uid=$(docker run --rm -e "TARGET_UID=$HOST_UID" -v "$HOSTDIR:/data" "$IMG_ENTRY" 'id -u; echo done > /data/state/written' | head -1)
    entry_owner=$(stat -c '%u' "$ROOTDIR/written" 2>/dev/null || echo NONE)
    rm -rf "$ROOTDIR" 2>/dev/null && after_cure=REMOVED || after_cure=DENIED

On a full base image this step is written with gosu (the Debian world) or su-exec
(the Alpine world); here the base is busybox and the gesture is the same: exec
replaces the process instead of sitting on top of it, so the command stays PID 1 as
in chapter 10. At the end, the tree that was locked comes away with no privileges at
all.

Once the six TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- ipermessi.sh reproduces the mismatch: a UID that does not own the folder is refused
  (TODO 1).
- It fixes it by running the container with the owning UID (TODO 2).
- It checks from the host the ownership of the created file (TODO 3).
- It reproduces the tree left by root and the refused removal (TODO 4).
- It cures it with USER declared in the image (TODO 5).
- It cures it with the entrypoint that fixes and hands over (TODO 6).
- run.sh prints OK 1..6 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — mismatch: the container with a UID that does not own the folder does not
  write (result DENIED).
- **OK 2** — cure: the same container, with the owning UID, writes (result WROTE).
- **OK 3** — no translation: the file created by the container is owned, on the host,
  by the same UID the container ran as.
- **OK 4** — the root-owned files problem: the tree the root container created belongs
  to UID 0 on the host, and your user cannot remove it.
- **OK 5** — cure with USER: the image declaring your UID writes with no flag at run
  time, and the file it creates is yours.
- **OK 6** — cure with the entrypoint: after the chown the process runs as your UID,
  what it writes is yours, and the tree root had locked now comes away with no
  privileges.

## Reflection questions

**a.** At a mount's boundary permissions apply by numeric UID/GID, not by user name:
why? What does the kernel actually see when the container writes, and why is the name
"appuser" inside the image (chapter 12) irrelevant next to the number it maps to?

**b.** There are three ways to make the numbers match: run the container with --user
equal to the UID that owns the files; chown the folder to the container's UID; or
create the user in the image with the same numeric UID as the data. What are the pros
and cons of each, in development and in production?

**c.** The USER namespace (chapter 2) can remap UIDs: container-root becomes an
unprivileged subuid on the host. How does the picture change with userns or in
rootless mode, and why — without remapping — does UID N in the container stay exactly
UID N on the host?

## Cleanup

Nothing to tear down by hand: the containers are throwaway (--rm), the two images
the scenario builds are removed by a trap, and the shared folder lives in a
temporary directory that run.sh clears itself — the last root-owned leftover, if
any, is taken away from inside a container and never with sudo. The busybox base
image stays in cache (shared). The daemon is never restarted.

## Where it leads

With this chapter Part 4 is complete: you know where to keep data, with which mount
and with which permissions. **Part 5** changes dimension: no longer storage but the
**network**. **Chapter 16** opens the labyrinths of networking — how Docker
manipulates Linux's network stack (network namespaces, veth, bridge) to give each
container its own address. For the command reference, see the volume's appendices.
