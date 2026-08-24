# Chapter 23 — King only in his own room

**Level:** Cloud Architect

We open Part 7 — security and day-2 — from the question underneath everything: who is
root, really? In classic Docker the daemon runs as root on the host, and whoever can
talk to it (the docker group) is root to all intents. A container running as root is
root on the host for the files it mounts, and an escape is an escape from root.
Rootless mode flips the picture using the USER namespace of chapter 2: the daemon and
the containers run inside a namespace where you are "root", but that root is mapped to
an unprivileged user on the host. You are king in your own room, an ordinary user
outside. In this lab you touch the mapping first-hand: inside you are uid 0 with all
the capabilities, outside you are your own user, and that "root" can do nothing
privileged on the host.

## Objectives

- Enter a USER namespace that maps you to root and see that inside you are uid 0
  (23.2).
- Verify that that root is mapped to your real, unprivileged user on the host (23.3).
- Observe that that "root" cannot touch the host's root-owned files — it is powerful
  only inside the namespace (23.3).
- Prove that whoever controls the rootful Docker daemon can read the host filesystem
  as uid 0 while remaining an unprivileged host user (23.1).
- Isolate the cause by running the same mount as an unprivileged UID (23.4).
- Understand why this model shrinks the blast radius of an escape (23.4).

## Prerequisites

- A Linux with **unprivileged user namespaces enabled** (default on modern
  distributions; it is what Docker rootless uses). You need the unshare command
  (util-linux). No sudo.
- Docker installed, a reachable daemon, and membership in the docker group, as
  described in ../../SETUP.md. Run the exercise as an unprivileged user, never as
  root: the contrast depends on this condition.
- Chapter 2 (namespaces, including the USER namespace) and chapter 12 (non-root
  containers): here you see what is underneath.

## The scenario

In start/ you will find rootless.sh: a script that should enter a user namespace and
measure the UID mapping and the limits of that "root", but five key measurements are
missing. You fill five gaps (TODO 1..5). The first three use only unshare; the final
two query Docker without reconfiguring its daemon.

The demonstration is deliberately harmless: it mounts / at /host read-only, writes
nothing to the host, and reads no credential file. The probe path is chosen by the
script: the first of /root and /var/lib/docker that your own user cannot open. Of
that path it only checks whether it opens, never listing or printing its contents.

Prepare the environment:

    cd docker/ed1/cap23/start

### Phase 1 — Root in your own room (23.2 — TODO 1)

Open start/rootless.sh and complete **TODO 1**: enter a user namespace that maps your
user to root, and read the uid. Inside you are 0 — "root".

    inner_uid=$(unshare --user --map-root-user id -u)

### Phase 2 — But which root? (23.3 — TODO 2)

Complete **TODO 2**: from inside, create a file "as root", then look from the host at
who owns it. It is not root's: it is your real user's. The namespace's root is mapped
to your unprivileged UID.

    unshare --user --map-root-user sh -c "touch '$OUT/asroot'"
    owner_uid=$(stat -c '%u' "$OUT/asroot")

### Phase 3 — Powerful only inside (23.3 — TODO 3)

Complete **TODO 3**: try, "as root" in the namespace, to write to a host root-owned
path (/etc). It cannot: the capabilities hold inside the namespace, not on the host.

    host_write=$(unshare --user --map-root-user sh -c 'touch /etc/rootless-probe 2>/dev/null && echo YES || echo NO')

### Phase 4 — From the docker group to the host filesystem (23.1 — TODO 4)

Complete **TODO 4**: try to open the probe path as your user — permission is denied,
and that is the control without which the rest would prove nothing. Then ask the
daemon for a container with / mounted read-only at /host: inside you are uid 0, and
the same path opens. Read its owner and permissions too, which say why it was closed
before.

    direct_read=$(ls -A "$probe" >/dev/null 2>&1 && echo YES || echo NO)
    root_probe=$(docker run --rm --name "$ROOT_CONTAINER" -v /:/host:ro "$IMAGE" sh -c 'printf "%s:%s:%s:" "$(id -u)" "$(stat -c %u "/host$1")" "$(stat -c %a "/host$1")"; ls -A "/host$1" >/dev/null 2>&1 && echo YES || echo NO' sh "$probe")

### Phase 5 — It is not the mount, but who you ask to be (23.4 — TODO 5)

Complete **TODO 5**: repeat with the same image and the same read-only mount, but pass
--user with your unprivileged UID:GID. The path closes again. The mount exposes the
filesystem; the power to traverse it comes from the uid 0 you asked the daemon for. In
rootless mode that uid 0 is remapped elsewhere, exactly as in Phases 1-3.

    user_read=$(docker run --rm --name "$USER_CONTAINER" --user "$outer_uid:$outer_gid" -v /:/host:ro "$IMAGE" sh -c 'ls -A "/host$1" >/dev/null 2>&1 && echo YES || echo NO' sh "$probe")

Once the five TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- rootless.sh reads the uid inside the user namespace (TODO 1).
- It reads the host owner of a file created "as root" inside (TODO 2).
- It checks whether that "root" can write to the host's /etc (TODO 3).
- It contrasts direct denial with daemon-mediated uid 0 access through a read-only
  host filesystem mount (TODO 4).
- It repeats the same mount as the unprivileged UID and gets denial again (TODO 5).
- run.sh prints OK 1..5 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — inside the user namespace you are uid 0: "root".
- **OK 2** — that root is mapped to your real (unprivileged) user: the file created
  "as root" is owned by your UID on the host, which is not 0.
- **OK 3** — that "root" cannot write the host's root-owned files: it is powerful only
  inside the namespace.
- **OK 4** — the host user cannot open the probe path, while the daemon-requested uid
  0 container opens it through the read-only mount; the path's owner and mode, both
  printed, say why the control holds.
- **OK 5** — the same image and mount, run as the unprivileged UID, stay out: the
  difference is who the daemon runs.

## Reflection questions

**a.** In rootful Docker the daemon runs as root and the socket is its door: why does
belonging to the docker group amount to being root on the host (you already met this
in chapter 5)? What, concretely, can whoever writes to that socket do?

**b.** Rootless mode uses the USER namespace of chapter 2 to remap UIDs: root in the
container (0) becomes an unprivileged subuid on the host. What does it mean that the
capabilities are "namespaced" — why do you see a full CapEff inside but that root is
powerless on the host? How does it connect to mounted files (chapter 15)?

**c.** Why does rootless shrink the blast radius of an escape: a process that breaks
out of the container finds itself an unprivileged user, not root on the host. What are
the practical limits of rootless (ports below 1024, some features that need real
privilege) and when do you accept them?

## Cleanup

Nothing to tear down by hand: run.sh removes its temporary directory and the cap23
containers even on error; unshare leaves no process nor namespace after it exits. The
mounts are read-only and disappear with the containers. The daemon is not
reconfigured.

## Where it leads

You saw the privilege model from the bottom up. **Chapter 24** stays on security but
changes the lever: not who you are, but what you can do — the capabilities granted to
or dropped from a container, and the seccomp and AppArmor/SELinux filters that
restrict syscalls and accesses. For the reference, see the volume's appendices.
