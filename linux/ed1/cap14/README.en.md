# Chapter 14 — Trigger Faults and Watch Them Happen

> Exercise for **Chapter 14 — Paging, Page Faults, and Swap** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- distinguish minor and major faults by measuring two reads of the same file;
- watch copy-on-write create private copies one page at a time after fork;
- recognize the onset of thrashing from scans, refaults, and memory pressure;
- contain a memory-pressure experiment in a resource-limited cgroup.

## Prerequisites

- A Linux host with a C compiler, Bash, and /usr/bin/time.
- Docker for the memory-pressure experiment only.
- Permission to use the Docker daemon.
- About 100 MiB of free space for temporary lab files.

## Instructions

1. Compile fault-stats.c, prepare a 64 MiB file, and read it one page at a time. The prepare command synchronizes the file and asks the kernel to evict its pages from the cache, giving the first measurement a good chance of requiring real I/O:

       gcc -O2 -Wall -Wextra solution/fault-stats.c -o /tmp/labcap14-fault-stats
       /tmp/labcap14-fault-stats prepare /tmp/labcap14-pages.bin 64
       /usr/bin/time -v /tmp/labcap14-fault-stats read /tmp/labcap14-pages.bin
       /usr/bin/time -v /tmp/labcap14-fault-stats read /tmp/labcap14-pages.bin

   Compare Minor page faults and Major page faults in the two runs. The first read brings pages into the page cache; the second reuses resident data. Exact counts depend on the filesystem and the kernel's read-ahead policy.

2. Compile and run cow-pages.c. The parent initializes the pages before fork; the child modifies them one at a time and prints the cumulative increase in minor faults:

       gcc -O2 -Wall -Wextra solution/cow-pages.c -o /tmp/labcap14-cow-pages
       /tmp/labcap14-cow-pages 16

   Explain why each write causes a minor fault even though it reads nothing from disk.

3. Run the short workload only inside the limited container. The script grants 96 MiB of memory, no more than half a CPU, and a 20-second deadline:

       solution/run.sh

   In the memory-pressure section, compare pgscan, pgsteal, workingset_refault_file, and the some value from memory.pressure before and after the workload. Repeated increases, memory close to the limit, and time spent stalled are symptoms of a working set that cannot remain resident. If Docker is unavailable, never replace this step with an equivalent host workload: record that the test was skipped.

4. Record measurements and explanations in start/observations.md. Remove any temporary files left by commands you ran manually.

## Definition of "done"

- [ ] You recorded minor and major faults for the first and second reads of the same file.
- [ ] You observed minor faults increase while the child modified shared pages after fork.
- [ ] You explained the relationship between copy-on-write and minor faults.
- [ ] You ran memory pressure only in a container with explicit limits and a timeout, or documented why the daemon was unavailable.
- [ ] You compared at least two metrics among scans, refaults, and memory pressure.
- [ ] No lab container or process remains after completion.
