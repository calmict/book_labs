# Chapter 3 - The ceiling and the OOM - answers

## The completed TODOs

TODO 1 (3.4) - the memory ceiling on the transient scope. Without it systemd-run
creates a cgroup with no limit, so nothing is ever killed:

    CAP=(--user --scope -q -p MemoryMax=40M -p MemorySwapMax=0)

  MemoryMax is the cgroup v2 memory.max; MemorySwapMax=0 disables swap so the
  process cannot escape the limit by paging out.

TODO 2 (3.5) - run the greedy allocator under the cap and record its exit code.
When it passes memory.max the OOM killer sends SIGKILL, so the code is 137:

    echo "greedy_capped_rc=$(rc systemd-run "${CAP[@]}" python3 -c "$greedy")" >> "$OUT/mem.txt"

TODO 3 (3.4) - the contrast, the same greedy allocation with no ceiling:

    echo "greedy_uncapped_rc=$(rc systemd-run "${NOCAP[@]}" python3 -c "$greedy")" >> "$OUT/mem.txt"

## Reflection answers

a. The exit code 137 is 128 + 9: by convention a process killed by signal N ends
with code 128+N, and signal 9 is SIGKILL. The OOM killer, when a cgroup exceeds
memory.max and no memory can be reclaimed, terminates a process inside that cgroup
with SIGKILL - hence 137. It is the same signature you will read in chapter 26 to
diagnose a container that "dies on its own": 137 almost always means it exceeded
its --memory, not an application bug.

b. The cap is the killer, not the allocation. Under a 40 MiB ceiling the greedy
process is OOM-killed; without the ceiling the very same 200 MiB allocation
completes fine (exit 0). This proves the limit did its job: it isolated the
damage to the offending cgroup. The lesson for production is that raising the cap
blindly is the wrong fix - first understand why the process grows; the cgroup
gives you the numbers to do so.

c. This exercise runs rootless, with no sudo, because on cgroup v2 systemd
delegates a subtree of the cgroup tree to each user (the "systemd owns the tree,
delegation" idea of section 3.7). systemd-run --user creates a transient scope in
that delegated subtree and can set memory.max on it. It is the same mechanism by
which the daemon's containers get their own cgroup under a delegated slice - and
the same foundation on which rootless Docker (chapter 23) stands. Note that not
every controller is always delegated: the memory controller is here, the cpu
controller may not be, which is why a CPUQuota may have no effect without it.
