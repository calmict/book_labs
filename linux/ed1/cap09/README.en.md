# Chapter 9 — X-Ray a Process

> Exercise for **Chapter 9 — Anatomy of a Process** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- inspect a live process's state, memory, open descriptors, and namespaces through /proc;
- recognize a zombie and relate it to a missing wait call in its parent;
- distinguish interruptible sleep S from uninterruptible sleep D;
- experimentally verify the effect of SIGKILL on a process blocked on a FIFO;
- (optional step, needs sudo) produce a genuine D state with a device-mapper `delay` target, and see why a FIFO cannot.

## Prerequisites

- A Linux host with /proc mounted.
- A C compiler and the bash, ps, awk, sed, readlink, and mkfifo commands.
- No administrative privileges for the first three steps. The lab creates only processes owned by the current user and a temporary directory prefixed with labcap09.
- For the optional genuine-D-state step: administrative privileges and the dmsetup, losetup, truncate, and dd commands (device-mapper and util-linux packages, almost always already present). Without sudo that step is skipped with an explicit message; the rest of the lab still runs.

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

   A FIFO therefore does not produce the D state required by the original lab wording and cannot demonstrate that SIGKILL remains pending during an uninterruptible wait. A real D state depends on a kernel path that uses TASK_UNINTERRUPTIBLE, typically during particular I/O waits. Producing one would require a different mechanism and additional isolation — step 6 does exactly that, without replacing this measurement with an incorrect label.

6. Optional step, needs sudo: produce a genuine D state with the device-mapper `delay` target. The script creates a 32 MB backing file, attaches it to a loop device, and maps a `delay` device on top that delays every I/O by 5 seconds:

      sudo dmsetup create labcap09-delay --noudevsync --table "0 65536 delay /dev/loopN 0 5000"

   `--noudevsync` avoids a wait (potentially forever, on some machines) for a udev acknowledgment that the kernel owes no one, having already created the device — a real trap hit while building this lab, not a theoretical one. A read with `dd ... iflag=direct` against the resulting device shows `ps` reporting STAT `D` and `/proc/PID/status` reporting `State: D (disk sleep)` for the whole delay: `iflag=direct` is required because a buffered read can be served straight from the cache and return instantly without ever passing through the delay.

   A second real trap: the system's udev rules run `blkid` against every new device-mapper node and set a watch on it — against a `delay` device even blkid's own probe costs the full delay, and `dmsetup remove` refuses a device that is still open, so the result is a `Device or resource busy` that no amount of retrying resolves by itself. The script installs a temporary, volatile udev rule (in `/run/udev/rules.d/`, gone on the next reboot), scoped to the single name `labcap09-delay`, telling udev to leave this device alone entirely; it always removes that rule at the end, along with the device and the loop device, even on error.

7. Run the complete solution and retain its output:

      solution/run.sh

   The final trap terminates only the PIDs recorded by the lab, removes the device-mapper node and loop device if created, and deletes the temporary directory. To include step 6 as well: `sudo solution/run.sh`.

## Definition of "done"

- [ ] You found the file held open by the test process through /proc.
- [ ] You read VmRSS, smaps_rollup, and the process's namespace links.
- [ ] You observed state Z and its disappearance after waitpid.
- [ ] You observed that the FIFO wait is S, not D.
- [ ] You verified that SIGKILL terminates the FIFO-blocked process with wait status 137.
- [ ] You recorded why the FIFO cannot demonstrate the D state, without claiming it was verified anyway.
- [ ] (if you ran step 6) You observed STAT `D` and `State: D (disk sleep)` during the wait on the dm-delay device, and a non-zero `dmsetup status` counter while the I/O was pending.
- [ ] No labcap09 process, device-mapper node, loop device, or temporary file remains at the end.

## Safety

Send signals only to PIDs printed by the script. Do not select real processes from ps output. The solution mounts no filesystems and changes no kernel settings. The first three steps require no sudo. Step 6 (dm-delay) requires sudo to create a device-mapper node: it works exclusively on a backing file created by the script, never on a real device or volume, and always removes it, even on error — it never touches the machine's existing LVM volumes or disks.
