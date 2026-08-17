# Chapter 21 — Deleting a File You Cannot Read

> Exercise for **Chapter 21 — Permissions, Setuid, and Capabilities** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- connect file creation and deletion to directory permissions rather than file permissions;
- distinguish directory traversal from directory listing;
- compare a setuid-root executable with the same executable carrying only the capability it needs;
- verify effective privileges and cleanup without modifying host binaries or accounts.

## Prerequisites

- A Linux host with Bash, coreutils, and a C compiler.
- A working Docker installation and a rockylinux:9 image available locally or ready to download for the unprivileged-user test.
- Kernel support for file capabilities.
- No important data in solution/labcap21-work: the script recreates and removes it.

## Instructions

1. In a test directory you own, create a file and remove all of its permissions. Verify that cat fails but rm succeeds while the directory grants write and search permission.

       mkdir labcap21-delete
       printf 'secret\n' > labcap21-delete/unreadable.txt
       chmod 000 labcap21-delete/unreadable.txt
       cat labcap21-delete/unreadable.txt
       rm labcap21-delete/unreadable.txt

2. Recreate the file. First remove directory write permission while retaining search permission, then remove search permission while retaining write permission. rm must fail in both cases. Always restore mode 0700 before cleanup.

       chmod 500 labcap21-delete
       rm labcap21-delete/unreadable.txt
       chmod 600 labcap21-delete
       rm labcap21-delete/unreadable.txt
       chmod 700 labcap21-delete

3. Create a second directory containing a readable file whose name is known. Give the directory search permission only, mode 0111. Verify that cat succeeds with the known path while ls on the directory fails: looking up a known entry and obtaining the full list are different operations.

       chmod 111 labcap21-traverse
       cat labcap21-traverse/known.txt
       ls labcap21-traverse

4. Compile raw_socket_probe.c, a small program that opens a raw ICMP socket and sends no packets. Start an ephemeral container with a labcap21user account and copy the program into an isolated scratch directory. Never apply setuid or setcap to the source file, a system binary, or any file outside that scratch directory.

5. As labcap21user, verify that the unprivileged copy cannot open the socket. Temporarily make only the copy root-owned and setuid, then verify that it works with EUID 0. Remove setuid and grant only cap_net_raw:

       chown root:root raw-socket-probe
       chmod 4755 raw-socket-probe
       runuser -u labcap21user -- ./raw-socket-probe
       chmod u-s raw-socket-probe
       setcap cap_net_raw=ep raw-socket-probe
       getcap raw-socket-probe
       runuser -u labcap21user -- ./raw-socket-probe

   The second run must open the socket while retaining an unprivileged EUID. The capability grants the specific network operation required, whereas setuid gives the process the full root identity.

6. Remove the container, scratch directory, and all test directories even if a step fails. Record the output in answers.md, or run the solution:

       ./solution/run.sh

## Definition of "done"

- [ ] You deleted an unreadable file by relying on directory write and search permission.
- [ ] You saw rm fail both without directory write permission and without directory search permission.
- [ ] A known path works in a mode 0111 directory, but ls is denied.
- [ ] Setuid and setcap were applied only to the copy in the container's isolated scratch directory.
- [ ] The setuid test works with EUID 0; the cap_net_raw test works while retaining labcap21user's EUID.
- [ ] No host account, security attribute, container, or test file remains.

