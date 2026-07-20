# Chapter 3 — The ceiling and the OOM

**Level:** Intermediate

The namespaces of chapter 2 decide *what* a process sees. But the other half of isolation is missing, and
without it a container would be a dangerous neighbour: *how much* it can consume. In this lab you impose a
memory ceiling on a process by hand and force it to break through, to watch the **OOM killer** strike with
your own eyes — and to read that exit code 137 you will meet again in production. All rootless, because
systemd's delegation (3.7) gives you a piece of the cgroup tree with no need for sudo.

## Objectives

- Impose a memory ceiling on a cgroup with systemd-run --user, without sudo (3.4, 3.7).
- Trigger the OOM killer and recognise its signature: exit code 137 (3.5).
- Prove the ceiling isolates the damage: without it the same allocation is harmless (3.4).
- Connect 137 to its cause (128 + 9 = SIGKILL), the diagnosis of chapter 26 (3.5).

## Prerequisites

- A Linux with cgroup v2 (the default today: check with stat -fc %T /sys/fs/cgroup, it must say
  cgroup2fs), systemd, python3 and systemd-run: no Docker needed.
- The memory controller delegated to your user by systemd (usually it is). No root: we use the
  delegation of section 3.7, not /sys/fs/cgroup by hand as root.
- The namespaces of chapters 1 and 2 as context: here we add the second box of the kernel.

## The scenario

In start/ you will find iltetto.sh: a script that should impose a memory ceiling and watch the OOM, but
the ceiling is missing, so no process is ever killed. You fill three gaps (TODO 1..3) so the ceiling
bites and the contrast proves it.

Prepare the environment:

    cd docker/ed1/cap03/start

### Phase 1 — Two mechanisms, one container (3.1)

Namespaces plus cgroups is the founding pair: the first isolate the view, the second the resources. A
container is a process with both applied. Remove the namespaces and it sees everything; remove the
cgroups and it can take everything, starving the neighbours. Here you drive the second half.

### Phase 2 — The memory ceiling (3.4 — TODO 1)

Open start/iltetto.sh and complete **TODO 1**: give the scope a memory ceiling. Complete the CAP array
with a 40 MiB limit and swap disabled, so the limit truly bites —

    CAP=(--user --scope -q -p MemoryMax=40M -p MemorySwapMax=0)

MemoryMax is the cgroup v2 memory.max; MemorySwapMax=0 disables swap, so the process cannot escape the
limit by paging out.

### Phase 3 — Breaking the ceiling (3.5 — TODO 2)

Complete **TODO 2**: run the greedy allocator (it asks for 200 MiB) UNDER the cap and record its exit
code in mem.txt as greedy_capped_rc. When it passes memory.max, the OOM killer sends it SIGKILL, and the
exit code is 137 (128 + 9).

### Phase 4 — The contrast (3.4 — TODO 3)

Complete **TODO 3**: run the *same* greedy allocator WITHOUT a cap (the NOCAP scope) and record its exit
code as greedy_uncapped_rc. It should be 0: the allocation itself is harmless; the cap is what kills. It
is the proof that the limit does its job, isolating the damage to the one cgroup that overflows.

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- The CAP array imposes MemoryMax=40M and MemorySwapMax=0 (TODO 1).
- greedy_capped_rc records the greedy exit code under the cap (TODO 2).
- greedy_uncapped_rc records the greedy exit code without a cap (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED: greedy under the cap is killed (137), the frugal one
  survives (0), greedy without a cap survives (0).

## How it is verified

solution/run.sh imposes the ceiling and checks, point by point:

- **OK 1** — the greedy process passes memory.max and is killed by the OOM killer: exit 137.
- **OK 2** — a frugal process under the same ceiling survives: exit 0.
- **OK 3** — the gate is the ceiling: without it the same allocation is harmless (exit 0). The limit has
  isolated the damage to the one overflowing cgroup.

## Reflection questions

**a.** Why is the exit code exactly 137? Break the number down and connect each piece to what happened.
Why, meeting a container dead with code 137 in chapter 26, will you already know the diagnosis without
opening anything?

**b.** With the cap the greedy process dies, without the cap the same 200 MiB allocation completes. What
does this contrast prove about the role of the limit? And why, in production, is raising the cap blindly
the wrong cure?

**c.** This lab runs rootless, with no sudo. Thanks to which systemd mechanism (3.7)? Why is the same
mechanism the foundation on which rootless mode (chapter 23) stands? And why might a CPU quota have no
effect, while the memory ceiling does?

## Cleanup

Nothing to tear down: each transient systemd-run scope ends with its process and is collected on its own,
and the test works in a temporary directory it cleans up itself. No cgroup left behind, no Docker
container.

## Where it leads

With this chapter the foundation is complete: you know *what* a container sees (namespaces) and *how much*
it can consume (cgroups). **Chapter 4** closes the theory with Copy-on-Write and OverlayFS — how a stack
of read-only layers, mounted inside the MNT namespace of chapter 2, produces the illusion of "another
Linux" without wasting disk.
