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
- Understand why this model shrinks the blast radius of an escape (23.4).

## Prerequisites

- A Linux with **unprivileged user namespaces enabled** (default on modern
  distributions; it is what Docker rootless uses). You need the unshare command
  (util-linux). No sudo, no Docker: this chapter works on the kernel mechanism under
  rootless.
- Chapter 2 (namespaces, including the USER namespace) and chapter 12 (non-root
  containers): here you see what is underneath.

## The scenario

In start/ you will find irootless.sh: a script that should enter a user namespace and
measure the UID mapping and the limits of that "root", but the three key measurements
are missing. You fill three gaps (TODO 1..3). No privileges, no daemon touched: just
unshare, which runs as an ordinary user.

Prepare the environment:

    cd docker/ed1/cap23/start

### Phase 1 — Root in your own room (23.2 — TODO 1)

Open start/irootless.sh and complete **TODO 1**: enter a user namespace that maps your
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

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- irootless.sh reads the uid inside the user namespace (TODO 1).
- It reads the host owner of a file created "as root" inside (TODO 2).
- It checks whether that "root" can write to the host's /etc (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — inside the user namespace you are uid 0: "root".
- **OK 2** — that root is mapped to your real (unprivileged) user: the file created
  "as root" is owned by your UID on the host, which is not 0.
- **OK 3** — that "root" cannot write the host's root-owned files: it is powerful only
  inside the namespace.

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

Nothing to tear down by hand: the script works in a temporary directory that run.sh
cleans up itself; unshare leaves no process nor namespace after it exits. No daemon
touched, no privilege required.

## Where it leads

You saw the privilege model from the bottom up. **Chapter 24** stays on security but
changes the lever: not who you are, but what you can do — the capabilities granted to
or dropped from a container, and the seccomp and AppArmor/SELinux filters that
restrict syscalls and accesses. For the reference, see the volume's appendices.
