# Chapter 9 — X-Ray a Process

> Exercise for **Chapter 9 — Anatomy of a Process** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- inspect a live process's state, memory, open descriptors, and namespaces through /proc;
- recognize a zombie and relate it to a missing wait call in its parent;
- distinguish interruptible sleep S from uninterruptible sleep D;
- experimentally verify the effect of SIGKILL on a process blocked on a FIFO.

## Prerequisites

- A Linux host with /proc mounted.
- A C compiler and the bash, ps, awk, sed, readlink, and mkfifo commands.
- No administrative privileges. The lab creates only processes owned by the current user and a temporary directory prefixed with labcap09.

## Instructions

1. Read solution/process-lab.c and solution/run.sh. The helper program has three modes: it keeps a process with allocated memory and open files alive, creates a controlled zombie, and blocks while opening a FIFO that has no writers.

2. Start the inspection process through solution/run.sh. The script first displays the concise ps view, then reads these paths directly:

      /proc/PID/status
      /proc/PID/fd/
      /proc/PID/smaps_rollup
      /proc/PID/ns/

   Find labcap09-open-file.txt among the descriptor links, compare VmRSS with Rss, and notice that each entry under ns links to a kernel object identified by a type and inode.

3. Observe the zombie child before its parent calls waitpid:

      ps -o pid,ppid,stat,wchan,comm -p CHILD_PID
      sed -n '/^State:/p' /proc/CHILD_PID/status

   State Z and the PPID relationship show that the process has exited but still retains the information its parent needs to collect its exit status. The script sends SIGUSR1 to the parent, which calls waitpid, and verifies that the child's entry disappears from /proc.

4. Examine the FIFO test. Before the signal, the script displays ps, State from /proc, and wchan for the labcap09 process only. It then sends SIGKILL, reaps the process, and verifies that the PID no longer exists.

5. Record the actual result in start/observations.md. On Linux, opening or reading a FIFO while its counterpart is absent waits in interruptible sleep: ps reports S and the wait channel is commonly wait_for_partner or pipe_read. SIGKILL interrupts the wait and terminates the process.

   A FIFO therefore does not produce the D state required by the original lab wording and cannot demonstrate that SIGKILL remains pending during an uninterruptible wait. A real D state depends on a kernel path that uses TASK_UNINTERRUPTIBLE, typically during particular I/O waits. Producing one would require a different mechanism and additional isolation; do not replace the measurement with an incorrect label.

6. Run the complete solution and retain its output:

      solution/run.sh

   The final trap terminates only the PIDs recorded by the lab and removes the temporary directory.

## Definition of "done"

- [ ] You found the file held open by the test process through /proc.
- [ ] You read VmRSS, smaps_rollup, and the process's namespace links.
- [ ] You observed state Z and its disappearance after waitpid.
- [ ] You observed that the FIFO wait is S, not D.
- [ ] You verified that SIGKILL terminates the FIFO-blocked process with wait status 137.
- [ ] You recorded that the D-state demonstration cannot be performed with the stated mechanism, without claiming that it was verified.
- [ ] No labcap09 process or temporary file remains at the end.

## Safety

Send signals only to PIDs printed by the script. Do not select real processes from ps output. The solution mounts no filesystems, changes no kernel settings, and does not require sudo.
