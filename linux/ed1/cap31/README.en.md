# Chapter 31 — Setting a Ceiling

> Exercise for **Chapter 31 — Cgroups v2: Accounting and Limits** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Advanced

## Objectives

By the end of this lab you will be able to:

- create cgroup v2 subgroups only inside a delegated user scope;
- restrict a workload to half a CPU and read throttling data from cpu.stat;
- confine a memory allocator and observe an OOM kill limited to its group;
- compare the recoverable pressure created by memory.high with the hard boundary enforced by memory.max.

## Prerequisites

- A Linux host using the unified cgroup v2 hierarchy.
- An active systemd user session with systemd-run available.
- Bash, Python 3, timeout, and permission to create a scope with Delegate=yes.
- At least 128 MiB of available memory for a short test; the workload is still bounded by its own cgroup.

## Instructions

1. Copy the start directory to a working directory and complete observations.md.
2. Start the lab exclusively inside a delegated user scope:

       systemd-run --user --scope -p Delegate=yes ./cgroup-lab.sh

   Do not create cgroups directly under the root of /sys/fs/cgroup.
3. Inside the scope, move the control process to a dedicated cgroup, enable the cpu and memory controllers, and create the labcap31-cpu cgroup.
4. Set cpu.max to 50000 100000, run one CPU workload for three seconds, and compare nr_periods, nr_throttled, and throttled_usec before and after the run.
5. Create labcap31-high with memory.high set to 32 MiB and memory.max set to 96 MiB. Allocate 72 MiB, confirm that the workload completes, and verify that the high counter increases.
6. Run the same 72 MiB workload in labcap31-max, this time with memory.max set to 48 MiB, memory.high disabled, and memory.oom.group enabled. Confirm that the workload is killed and that oom_kill increases.
7. Record the counters in observations.md and explain why memory.high slows the workload and forces reclaim while memory.max prevents it from crossing the boundary.
8. Remove the child cgroups and let the scope finish. Verify that no lab processes remain.

The solution directory contains an executable solution:

    ./solution/run.sh

## Definition of "done"

- [ ] Every lab cgroup is a child of an explicitly delegated user scope.
- [ ] cpu.max represents half a CPU and cpu.stat reports at least one throttling event.
- [ ] The same 72 MiB workload survives memory.high but is killed by memory.max.
- [ ] memory.events reports an increase in high for the first case and oom_kill for the second.
- [ ] The control process remains outside the limited cgroups.
- [ ] Every workload is time-bounded and all temporary cgroups and processes are removed.
