# Chapter 15 — The number on the badge

**Level:** Advanced

You learned to run as a non-root user (chapter 12) and to mount shared data (chapter
14). Put the two together and you trip over the classic: the non-root container tries
to write to the volume and is told "permission denied". The reason is that at a
mount's boundary permissions are read not by name but by number: what counts is the
UID, a numeric badge. If the container's number does not own the mounted files, it
does not write — full stop. In this lab you reproduce the mismatch, fix it by running
the container with the right UID, and verify that the number crosses the boundary
unchanged: UID N inside is UID N on the host.

## Objectives

- See that on a shared mount permissions apply by numeric UID/GID, not by user name
  (15.1).
- Reproduce the problem: a container with a UID that does not own the folder cannot
  write (15.2).
- Fix it by running the container with the UID that owns the files (--user) (15.3).
- Verify the UID is not translated: the file the container creates is owned by the
  same UID on the host (15.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md), native (a bind mount uses the
  host's real permissions). Your user must be able to use Docker.
- Chapter 12 (non-root containers) and chapter 14 (bind mounts): here you make them
  collide with permissions.

## The scenario

In start/ you will find ipermessi.sh: a script that prepares a host folder you own,
mounts it in a container and should show the mismatch and its cure — but the three key
proofs are missing. You fill three gaps (TODO 1..3). Throwaway containers (--rm) and a
temporary folder: no privileges, the daemon is not touched.

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

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- ipermessi.sh reproduces the mismatch: a UID that does not own the folder is refused
  (TODO 1).
- It fixes it by running the container with the owning UID (TODO 2).
- It checks from the host the ownership of the created file (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — mismatch: the container with a UID that does not own the folder does not
  write (result DENIED).
- **OK 2** — cure: the same container, with the owning UID, writes (result WROTE).
- **OK 3** — no translation: the file created by the container is owned, on the host,
  by the same UID the container ran as.

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

Nothing to tear down by hand: the containers are throwaway (--rm) and the shared
folder lives in a temporary directory that run.sh cleans up itself. The busybox base
image stays in cache (shared). The daemon is never restarted.

## Where it leads

With this chapter Part 4 is complete: you know where to keep data, with which mount
and with which permissions. **Part 5** changes dimension: no longer storage but the
**network**. **Chapter 16** opens the labyrinths of networking — how Docker
manipulates Linux's network stack (network namespaces, veth, bridge) to give each
container its own address. For the command reference, see the volume's appendices.
