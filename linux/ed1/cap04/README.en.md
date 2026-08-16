# Chapter 4 — Read a Machine You Do Not Know

> Exercise for **Chapter 4 — Anatomy of an Installed System** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- derive a distribution's identity and family from /etc/os-release;
- identify the package manager and query its database;
- compare the running kernel with the packages declared as installed;
- use findmnt and lsblk to find directories backed by separate filesystems.

## Prerequisites

- A Linux host with Bash, uname, findmnt, and lsblk.
- rpm on an RPM-family distribution or dpkg-query on a Debian-family system.
- No administrative privileges are needed: every command is read-only.

## Instructions

Imagine facing an undocumented machine. Reconstruct its identity using only local
data and record your conclusions in start/answers.md.

1. Read the complete identity file, then extract the most useful fields instead of
   guessing the system from the appearance of its terminal:

       cat /etc/os-release
       . /etc/os-release
       printf 'ID=%s\nID_LIKE=%s\nPRETTY_NAME=%s\n' "$ID" "${ID_LIKE:-}" "$PRETTY_NAME"

   ID identifies the distribution. When present, ID_LIKE names the technical
   family whose conventions and tools it inherits.

2. Look for the package manager and verify your conclusion by querying the actual
   database. Use the branch that matches the machine:

       command -v dnf apt-get zypper pacman apk 2>/dev/null
       rpm -qf /usr/bin/bash
       dpkg-query -S /usr/bin/bash

   It is normal for one of the last two commands not to exist.

3. Record the kernel that is actually running:

       uname -r

   Then look for its matching declaration in the package database:

       rpm -q "kernel-core-$(uname -r)"
       dpkg-query -W "linux-image-$(uname -r)"

   Again, choose the command matching the distribution family. Do not alter the
   result if no package matches: a container may see its host's kernel without
   owning that package, while a system may have installed kernels it is not
   currently running.

4. Reconstruct the filesystem layout:

       findmnt --real -o TARGET,SOURCE,FSTYPE,OPTIONS
       lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINTS

   Compare the source mounted on / with those for /home, /var, /boot, and other
   directories. A different block source indicates a separate filesystem; a
   portion in square brackets identifies a subtree rather than a new independent
   partition.

5. Run the automated solution, which collects and checks the observations:

       solution/run.sh

## Definition of "done"

- [ ] You recorded the distribution, version, and family from /etc/os-release.
- [ ] You identified the package manager and queried one installed package.
- [ ] You compared uname -r with the package database declaration.
- [ ] You listed directories backed by block partitions other than the one for /.
- [ ] You distinguished a separate mount from a subtree of the same source.
- [ ] solution/run.sh completes all checks without changing the system.
