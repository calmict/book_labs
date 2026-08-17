# Chapter 26 — Seeing What Nobody Tells You

> Exercise for **Chapter 26 — System Calls, procfs, and sysfs: Looking Inside** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- use strace to find the system call behind an error that a program hides;
- recognize stdio buffering when stdout is connected to a pipe and fix it;
- read and change a network sysctl inside an isolated namespace;
- distinguish an immediate change from a configuration loaded at boot.

## Prerequisites

- A Linux system with Bash, Python 3, strace, iproute2, and procps.
- Administrative privileges to create the labcap26 network namespace.
- A rebootable test machine, only for the optional persistence check.

## Instructions

1. Enter the start directory and run silent_failure.py with a nonexistent file. The program exits with status 1 without printing a diagnosis. Run it again under strace, restrict the trace to openat, and save it to a file:

       python3 silent_failure.py /tmp/labcap26-missing.conf
       strace -f -e trace=openat -o /tmp/labcap26-strace.log \
         python3 silent_failure.py /tmp/labcap26-missing.conf
       grep 'labcap26-missing.conf' /tmp/labcap26-strace.log

   Record the failed system call, its return value, and the error code.

2. Connect buffered_writer.py to a pipe that writes to a file. Check the file size while the program is still paused. Repeat with Python's -u option:

       python3 buffered_writer.py | cat > /tmp/labcap26-buffered.out &
       sleep 0.2
       wc -c < /tmp/labcap26-buffered.out
       wait

       python3 -u buffered_writer.py | cat > /tmp/labcap26-unbuffered.out &
       sleep 0.2
       wc -c < /tmp/labcap26-unbuffered.out
       wait

   Explain why the first line remains buffered when stdout is not a terminal. Also try a source-level fix using flush=True.

3. Create the labcap26 namespace, read net.ipv4.ip_forward, set it to 0 and then to 1, and verify each value. Do not run these commands in the host network namespace:

       sudo ip netns add labcap26
       sudo ip netns exec labcap26 sysctl -w net.ipv4.ip_forward=0
       sudo ip netns exec labcap26 sysctl -n net.ipv4.ip_forward
       sudo ip netns exec labcap26 sysctl -w net.ipv4.ip_forward=1
       sudo ip netns exec labcap26 sysctl -n net.ipv4.ip_forward
       sudo ip netns del labcap26

4. Examine solution/99-labcap26.conf. On a test machine you own, never on a shared system, a file with that content installed as /etc/sysctl.d/99-labcap26.conf is loaded during boot. To perform the full check, install it, reboot the test machine, and verify it with:

       sysctl -n net.ipv4.ip_forward

   The file demonstrates the persistence mechanism, but no lab script installs it. A file under /etc/sysctl.d belongs to the machine's initial namespace and would not be a safe persistence test inside a temporary namespace.

5. Run the automated solution. Use sudo if you are not root. The script always removes its namespace, processes, and temporary files:

       sudo ./solution/run.sh

## Definition of "done"

- [ ] The trace shows openat returning -1 ENOENT for the missing file.
- [ ] You observed zero bytes during the buffered run and data already visible during the unbuffered run.
- [ ] You verified sysctl values 0 and 1 exclusively inside labcap26.
- [ ] You can explain the role of the file under /etc/sysctl.d and performed any reboot test only on a disposable machine.
- [ ] The labcap26 namespace and all temporary files have been removed.
