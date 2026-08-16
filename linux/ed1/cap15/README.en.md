# Chapter 15 — Fill Memory and See What Falls

> Exercise for **Chapter 15 — Allocation, Cache, and the OOM Killer** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- distinguish free memory from available memory as the page cache grows;
- observe that a large virtual allocation consumes no physical memory until its pages are touched;
- trigger a contained out-of-memory event and identify the process killed by the kernel;
- verify memory limits and the OOM outcome through container state.

## Prerequisites

- A Linux host with Docker installed and access to its daemon.
- Permission to run the python:3.12-alpine image, either locally available or downloadable.
- At least 250 MiB of temporary disk space.

## Instructions

Do not run this exercise directly on the host. The script creates three separate containers, each with equal memory and swap limits, half a CPU, a process limit, and a deadline. Run the complete experiment with:

    solution/run.sh

1. In the first container, inspect the readings before and after writing and synchronizing a 120 MiB file. /proc/meminfo is not cgroup-namespaced in a standard Docker installation, so the solution calculates two equivalent values within the lab limit:

       cgroup free = memory.max - memory.current
       cgroup available estimate = cgroup free + file cache, capped at memory.max

   Record how far the two values fall. The latter falls much less because it includes reclaimable file cache.

2. In the second container, the program creates a 1 GiB anonymous mapping without writing to it. Compare VmSize and memory.current before and after. VmSize grows by about 1 GiB while physical cgroup usage barely changes: this is overcommit before the pages are first accessed.

3. In the third container, an allocator touches 8 MiB blocks under a 128 MiB limit with no swap. The script assigns a positive oom-score-adj value, prints the process log, and checks:

       docker inspect --format 'oom={{.State.OOMKilled}} exit={{.State.ExitCode}}' labcap15-oom

   The expected result is oom=true and exit=137. This identifies the container process as the victim. Do not require dmesg: kernel messages are unavailable to unprivileged users in many environments. Container logs show the last completed allocation, while OOMKilled records the kernel's decision.

4. Record measurements and conclusions in start/observations.md. If the daemon is unavailable, record the skip and do not run any of the three programs directly on the host.

## Definition of "done"

- [ ] You compared free memory with an available-memory estimate before and after filling the page cache.
- [ ] You showed that virtual memory grows much more than physical memory for an untouched allocation.
- [ ] You obtained OOMKilled=true and exit code 137 for the OOM container only.
- [ ] You read the allocator log through the block immediately before termination.
- [ ] You verified that memory and memory-swap limits match for every container.
- [ ] No lab process or container remains active at the end.
