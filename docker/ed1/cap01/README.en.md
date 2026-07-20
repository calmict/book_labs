# Chapter 1 — The bare-hands container

**Level:** Foundational

The journey begins by dismantling the first illusion: that you have switched on a small machine. In this
lab you build a container **without Docker**, using only the unshare command, and prove with your own
eyes what the chapter announces — a container is not a ship of its own, it is an ordinary Linux process
that the kernel has told a restricted version of reality. Before you board Docker's engine, feel for
yourself what the hold is made of.

## Objectives

- Build a container by hand, with no Docker, using unshare (1.4).
- Prove from the inside that you are process number 1 of a new world (1.4).
- Isolate the hostname with a UTS namespace, without touching the host's (1.2, 1.4).
- Unmask the illusion from the outside: same kernel, different namespace (1.5).

## Prerequisites

- A Linux with the unshare command (util-linux) and ps: no Docker needed for this chapter.
- No root privileges: we use a USER namespace (--user --map-root-user) so the exercise runs without
  sudo. It is a preview of the "fake root" of chapter 2 and of rootless mode in chapter 23.

## The scenario

In start/ you will find manibnude.sh: a script that should build a bare-hands container but is
deliberately incomplete. As written it only opens a USER namespace and isolates nothing. Your job is to
fill three gaps (TODO 1..3) so that the child process is truly born into a separate world, and records
the proof that it is.

Prepare the environment:

    cd docker/ed1/cap01/start

### Phase 1 — A masked process (1.1)

When you run docker run and see a shell claiming to be inside Ubuntu, it feels like you switched on a
computer inside the computer. It is false: that world shares the very same kernel with your machine.
There is no second operating system, no boot. There is only a process to which the kernel shows a
restricted version of reality. In this lab you create that process yourself, by hand.

### Phase 2 — The views to isolate (1.4 — TODO 1)

A container is a process with a fresh instance of some kernel "worlds". Open start/manibnude.sh and
complete **TODO 1**: add to the unshare command the flags that create the isolation —

    unshare --user --map-root-user --uts --pid --fork --mount-proc \
      bash -c '...' bash "$OUT"

The --uts flag gives an isolated hostname; --pid --fork give a new process numbering with the shell as
PID 1; --mount-proc remounts /proc so it reflects the new PID namespace (otherwise ps would still show
the host's processes).

### Phase 3 — The proof from the inside (1.4 — TODO 2)

Inside the new world, complete **TODO 2**: change the hostname to nave-cargo and record the proof of
isolation — your PID (which must be 1), the number of visible processes, and the inode of your PID
namespace, read from /proc/self/ns/pid.

### Phase 4 — The view from the host (1.5 — TODO 3)

Finally complete **TODO 3**: before building the container, record the host's point of view — its
hostname and the inode of its PID namespace. It will be the yardstick: the host's inode differs from the
container's, the proof that the two live in separate worlds while sharing the same kernel.

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- manibnude.sh builds the container with the correct flags (TODO 1).
- From the inside the shell is PID 1 and the hostname is nave-cargo (TODO 2).
- From the host, the hostname is untouched and the PID-namespace inode differs from the inside one
  (TODO 3).
- run.sh prints OK 1..4 and ALL CHECKS PASSED, including the contrast check: without --pid the inside
  PID is no longer 1.

## How it is verified

solution/run.sh builds the bare-hands container and checks, point by point:

- **OK 1** — from the inside the shell is process number 1 of the new PID namespace.
- **OK 2** — the hostname is isolated: nave-cargo inside, the host unchanged outside.
- **OK 3** — the inside PID-namespace inode differs from the host's: separate worlds.
- **OK 4** — the gate bites: dropping --pid creates no PID namespace, and the inside PID is no longer 1.
  It is the proof that process isolation is exactly that flag.

## Reflection questions

**a.** From the host, the container you just created has an ordinary PID and you can end it with a plain
kill. What does this tell you about the nature of a container? And what makes it "feel" like a machine of
its own, if it is nothing but a process?

**b.** From the inside the shell is PID 1, from the host it has a large number. Are they the same process
or two different ones? Explain why the PID-namespace inode read from the inside matches the one the host
reads for that PID, yet differs from the host's own namespace inode.

**c.** By dropping the --pid flag, the inside PID is no longer 1. Which specific isolation did you lose?
And what does this tell you about whether a container's isolation is a single thing or the sum of several
independent views?

## Cleanup

Nothing to tear down: the bare-hands container is a process that ends by itself when the script finishes,
and the test works in a temporary directory it cleans up on its own. No Docker containers, no resources
left on the host.

## Where it leads

You built a container with a single isolation flag, and opened only one at a time. But --pid was the door
to a whole family of worlds. **Chapter 2** opens every door, one at a time: the namespaces — PID, NET,
MNT, UTS, IPC and the surprising USER, the "fake root" you already used here, without knowing it, to do
without sudo.
