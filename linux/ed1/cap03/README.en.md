# Chapter 3 — The Boundary, Seen from the Service Window

> Exercise for **Chapter 3 — Kernel and User Space: The Line Between Two Worlds** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- observe the requests a user-space program makes to the kernel;
- count and classify system calls with a strace summary;
- recognize ENOENT as the result of looking up a nonexistent file;
- distinguish the administrative identity UID 0 from the CPU's privileged mode.

## Prerequisites

- A Linux host with Bash and terminal access.
- strace installed, as verified by command -v strace.
- sudo and dnf to install strace if it is missing:

       sudo dnf install -y strace

- sudo for the final test with a UID 0 process. The observed commands are
  read-only and do not alter services or configuration.

## Instructions

1. Verify that strace is available:

       command -v strace

   If this prints no path, install the package shown in the prerequisites. If the
   system forbids ptrace, stop and record the message: having the executable
   installed does not necessarily grant permission to trace a process.

2. Count the kernel requests made by a very small command:

       strace -c /usr/bin/printf 'hello\n'

   The program writes one line, yet dynamic loading, memory, files, and exit
   require many system calls. Copy the summary to start/answers.md and record the
   total and the most frequent call.

3. Ask cat to open a name that certainly does not exist and restrict the trace to
   file operations:

       strace -e trace=openat,newfstatat,statx,access cat /tmp/labcap03-file-that-does-not-exist

   cat exits with an error. Find the line for that path, the system call name,
   and the ENOENT result.

4. Repeat the observation with a UID 0 process and save the trace:

       sudo strace -qq -e trace=openat,write -o /tmp/labcap03-root.trace sh -c 'printf "uid=%s\n" "$(id -u)"; cat /etc/os-release >/dev/null'

       grep -E 'openat|write' /tmp/labcap03-root.trace | head

   The printed value is 0, but the process still uses openat and write to request
   kernel services. root is an identity with special authorization; it does not
   mean that the process's ordinary code executes in kernel mode. Remove the
   temporary trace after recording the result.

5. Run the automated solution:

       solution/run.sh

   If sudo needs a password, run the command from an interactive terminal.

## Definition of "done"

- [ ] You recorded the strace -c summary and the total number of system calls.
- [ ] You found a failed openat with ENOENT for the nonexistent file.
- [ ] You traced a process that prints UID 0 and observed its system calls.
- [ ] You can explain why UID 0 and kernel mode are not the same thing.
- [ ] solution/run.sh passes its checks or explicitly reports a ptrace restriction.
- [ ] All temporary traces have been removed.
