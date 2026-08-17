# Chapter 30 — Building an Illusion

> Exercise for **Chapter 30 — Namespaces: The Kernel's Illusions** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Advanced

## Objectives

By the end of this lab you will be able to:

- create user, PID, network, UTS, and mount namespaces together without administrative privileges;
- compare the PIDs, hostname, and network seen from the host with the view inside an isolated shell;
- enter a process's namespaces from the outside with nsenter;
- interpret the mapping that makes a user root in a namespace without granting root privileges on the host.

## Prerequisites

- A Linux host with Bash, util-linux, and procps.
- Unprivileged user namespace creation must be enabled.
- No sudo access is required or should be used.

## Instructions

1. Copy the start directory to a working directory and complete observations.md.
2. Start an isolated shell. The following namespaces must be created together in the same command:

       unshare --user --map-root-user --pid --net --uts --mount --propagation private --fork /bin/sh

3. Set the hostname to labcap30-shell inside the shell. Record its PID, UID, hostname, network namespace link, and the contents of /proc/self/uid_map.
4. Mount a fresh proc view in the shell, then find the shell's real PID from the host. Compare its PID, UID, hostname, and network namespace with the values seen inside. Also verify that the isolated network contains only the loopback interface.
5. From the host, target the shell PID with nsenter and enter its user, mount, UTS, network, and PID namespaces. Start a new shell that displays its PID, UID, hostname, and network namespace.
6. In observations.md, explain why UID 0 inside the namespace maps to your regular host UID and why the new process started through nsenter cannot see host processes.
7. Stop the isolated shell and verify that no lab processes or resources remain.

The solution directory contains a timed, executable solution:

    ./solution/run.sh

## Definition of "done"

- [ ] The shell uses user, PID, network, UTS, and mount namespaces together with private propagation.
- [ ] The internal PID, hostname, and network namespace differ from the values observed on the host.
- [ ] nsenter starts a process from the outside that sees the same isolated view.
- [ ] /proc/self/uid_map proves that internal root maps to the unprivileged host UID.
- [ ] The isolated network contains only loopback and the shell cannot see host processes.
- [ ] All temporary processes and resources have been removed.
