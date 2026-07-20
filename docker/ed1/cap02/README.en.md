# Chapter 2 — The six rooms

**Level:** Foundational

In chapter 1 you detached a process from the list of the others with a single flag, and that process
found itself PID 1 of a world of its own. But that flag was a door onto a whole family of isolations. In
this lab you open almost all of them at once — hostname, processes, mounts, network, and the user
mapping — and prove, room by room, that a container's isolation is not one single wall but the sum of
several views the kernel agrees not to show.

## Objectives

- Build a process isolated in several namespaces at once, with no Docker and no sudo (2.1).
- Prove each room with its own evidence: PID (PID 1), UTS (hostname), MNT (a private mount), NET (a
  near-mute stack), USER (the fake root) (2.2-2.7).
- Use the inode in /proc/self/ns as the metric: a different inode means a separate world (2.1).
- See that dropping a flag removes a single room, not all of them (2.5).

## Prerequisites

- A Linux with unshare (util-linux), ip and mount: no Docker needed.
- No root: we use the USER namespace (--user --map-root-user), which is itself one of the six rooms —
  the one that makes us root inside without being root outside. The bare-hands container of chapter 1 is
  the starting point.

## The scenario

In start/ you will find lestanze.sh: a script that should build a process isolated in several namespaces
but only opens the USER namespace and isolates nothing else. You fill three gaps (TODO 1..3) so the
child is born into a separate world on several fronts and records the proof of each.

Prepare the environment:

    cd docker/ed1/cap02/start

### Phase 1 — What a namespace is (2.1)

A namespace partitions the view of a resource: it creates no new hardware, it only changes what a
process perceives. A process's membership in each namespace is readable in /proc/<pid>/ns as an inode:
two processes with the same inode share that world; with a different inode they live in separate worlds.
It is the metric we will use for every room.

### Phase 2 — Opening the rooms (2.2-2.5 — TODO 1)

Open start/lestanze.sh and complete **TODO 1**: add to the unshare command the flags that open one room
each —

    unshare --user --map-root-user --uts --pid --fork --mount-proc --mount --net \
      bash -c '...' bash "$OUT"

The --uts flag isolates the hostname; --pid --fork give the process numbering with the shell as PID 1;
--mount-proc remounts /proc; --mount gives a private mount table; --net gives a private, near-mute
network stack (only loopback).

### Phase 3 — The private-mount proof (2.4 — TODO 2)

Inside the child, complete **TODO 2**: mount a private tmpfs on /mnt and write a marker file into it.
That mount lives in the process's MNT namespace: the host will never see it, and the test verifies this.

    mount -t tmpfs tmpfs /mnt && echo mounted > /mnt/marker

### Phase 4 — The host's yardstick (2.1 — TODO 3)

Finally complete **TODO 3**: before building the isolated process, record the host's namespace inodes
(uts, pid, mnt, net). They will be the point of comparison: for each room, the inside inode differing
from the host's is the proof that the room exists.

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- lestanze.sh opens the correct namespaces (TODO 1) and creates the private mount (TODO 2).
- host.txt records the host's inodes (TODO 3).
- From the inside: PID 1, hostname sei-stanze, marker present, network with only loopback, uid 0.
- run.sh prints OK 1..6 and ALL CHECKS PASSED, including the contrast: without --net the process shares
  the host's network again.

## How it is verified

solution/run.sh builds the process and checks one room per assertion:

- **OK 1** — PID: from the inside the shell is process number 1.
- **OK 2** — UTS: hostname isolated (sei-stanze) and a uts inode different from the host's.
- **OK 3** — MNT: the private mount exists inside and is invisible to the host.
- **OK 4** — NET: a private, near-mute network stack (different inode, only loopback).
- **OK 5** — USER: root (uid 0) inside, while an unprivileged user outside.
- **OK 6** — the gate bites: dropping --net makes the process share the host's network again. The proof
  that isolation is the sum of the individual rooms, not a single switch.

## Reflection questions

**a.** Each namespace attacks a different view. Describe, for every room you opened, what it isolates
exactly — and explain why the inode in /proc/<pid>/ns is the proof that that single world is separate,
while everything else (the kernel above all) stays shared.

**b.** You are root inside (uid 0) but used no sudo. Which namespace makes this possible, and how? Why is
this same mechanism the basis of both rootless mode (chapter 23) and the "files owned by root" problem
(chapter 15)?

**c.** Dropping --net makes the process share the host's network again, yet it keeps its own PID, UTS and
MNT. What does this tell you about whether a container's isolation is one single thing or the sum of
several independent views? Which Docker network mode corresponds to "open five rooms and leave one
shared"?

## Cleanup

Nothing to tear down: the isolated process ends by itself when the script finishes, the private mount
lives only in its MNT namespace and disappears with it, and the test works in a temporary directory it
cleans up on its own. No Docker containers, no resources left on the host.

## Where it leads

You opened the rooms that decide *what* a process sees. But the other half of isolation is missing: *how
much* it can consume. **Chapter 3** opens the second box of the kernel, the cgroups — the counter and the
limiter — and has you impose a memory ceiling by hand until you watch the OOM killer strike live.
