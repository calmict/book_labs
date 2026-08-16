# Chapter 10 — Duplicate, Transform, Disappear

> Exercise for **Chapter 10 — fork, exec, wait: How a Process Is Born and Dies** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- observe the relationship between a parent process and the child created by fork() from the outside;
- prove that exec() replaces a program without changing its PID;
- recognize a zombie by its Z state and remove it by making the parent call wait().

## Prerequisites

- A Linux host with a C compiler, Bash, ps, and access to /proc.
- Basic familiarity with PIDs, PPIDs, and signals.
- No administrative privileges are required.

## Instructions

1. Copy start/process_lab.c to a working directory. Complete the three marked functions and compile the program:

       cc -std=c11 -Wall -Wextra -Wpedantic -O2 process_lab.c -o process_lab

2. In fork mode, create a child and keep both processes alive for a few seconds. Start the program in the background, then observe it from the outside:

       ./process_lab fork state &
       ps -o pid,ppid,stat,comm -p "$(cat state/parent.pid),$(cat state/child.pid)"

   Confirm that the child's PPID matches the parent's PID. The parent must eventually reap the child with waitpid().

3. In exec mode, save the PID and replace the program with sleep through exec. While sleep is running, compare the saved PID with the observed one:

       ./process_lab exec state &
       launched_pid=$!
       cat state/exec-before.pid
       ps -o pid,stat,comm -p "$launched_pid"

   The two PIDs must match, while the program name must have changed to sleep.

4. In zombie mode, let the child exit immediately without calling waitpid() in the parent yet. Observe the Z state:

       ./process_lab zombie state &
       ps -o pid,ppid,stat,comm -p "$(cat state/zombie-child.pid)"

5. Do not signal the zombie. Send SIGUSR1 to its parent instead; the parent must respond by calling waitpid():

       kill -USR1 "$(cat state/zombie-parent.pid)"
       ps -p "$(cat state/zombie-child.pid)"

   The second command must no longer find the child's PID. Record your observations and answers in answers.md.

6. Run the complete solution to compare it with your result:

       ./solution/run.sh

## Definition of "done"

- [ ] ps shows the parent and child at the same time, with the correct PID/PPID relationship.
- [ ] The PID before and after exec is identical, and the program observed after exec is sleep.
- [ ] The terminated child appears in state Z before the parent's wait call.
- [ ] After SIGUSR1 is sent to the parent, the zombie's PID no longer exists.
- [ ] Every test process has exited and the temporary directory has been removed.
