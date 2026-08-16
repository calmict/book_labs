# Chapter 13 — Two Processes, One Address, Two Memories

> Exercise for **Chapter 13 — Virtual Memory: Addresses That Lie** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- prove that two processes can use the same virtual address for different contents;
- read /proc/PID/maps and interpret the permissions and purpose of its main regions;
- measure RSS and PSS in /proc/PID/smaps_rollup and explain how shared pages are accounted for.

## Prerequisites

- A 64-bit Linux host with a C compiler, Bash, and access to /proc for your own processes.
- The ps, awk, grep, and ldd commands.
- No administrative privileges are required.

## Instructions

1. Copy start/memory_lab.c to a working directory. Complete the program so it reserves one private anonymous page at address 0x500000000000 with mmap(). Use MAP_FIXED_NOREPLACE: an error must stop the experiment rather than replace an existing mapping.

2. Start two instances at the same time with different labels:

       cc -std=c11 -Wall -Wextra -Wpedantic -O2 memory_lab.c -o memory_lab
       ./memory_lab alpha state &
       alpha_pid=$!
       ./memory_lab beta state &
       beta_pid=$!
       cat state/alpha.initial state/beta.initial

   Both must report 0x500000000000, but one page contains alpha while the other contains beta.

3. Send SIGUSR1 only to alpha to modify its page, then use SIGUSR2 to request a fresh snapshot from both instances:

       kill -USR1 "$alpha_pid"
       kill -USR2 "$alpha_pid" "$beta_pid"
       cat state/alpha.snapshot state/beta.snapshot

   Alpha's page must contain alpha-changed, while beta's must still contain beta. An identical address does not imply shared memory: each page table translates it independently.

4. Read one instance's map while it is running:

       cat "/proc/$alpha_pid/maps"

   Find and record at least these regions:

   - the executable file, with read-only, executable, and writable segments;
   - the heap and stack, which are normally private and writable;
   - the anonymous page at the selected address, private and writable;
   - dynamic libraries and the linker, with segments carrying different permissions;
   - vvar and vdso, exposed by the kernel.

   Interpret the permission characters: r means readable, w writable, x executable, p private mapping, and s shared mapping. A dash means the permission is absent.

5. Read Rss and Pss for both instances:

       awk '$1 == "Rss:" || $1 == "Pss:" { print }' "/proc/$alpha_pid/smaps_rollup"
       awk '$1 == "Rss:" || $1 == "Pss:" { print }' "/proc/$beta_pid/smaps_rollup"

   RSS charges each process the full cost of every resident page it maps. PSS divides the cost of each shared page by the number of processes sharing it. Compare the sum of both RSS values with the sum of both PSS values as well.

6. Terminate both instances with SIGTERM and verify that neither remains active. Record measurements and interpretation in observations.md. The solution automates the experiment:

       ./solution/run.sh

## Definition of "done"

- [ ] Two distinct processes report the same virtual address and different initial values.
- [ ] Changing alpha's page does not alter the value observed by beta.
- [ ] You identified the executable, heap, stack, anonymous page, libraries, vvar, and vdso from their permissions.
- [ ] You measured RSS and PSS for both instances and explained why PSS is lower when pages are shared.
- [ ] Both test processes have exited and temporary files have been removed.
