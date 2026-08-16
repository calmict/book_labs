# Chapter 17 — One Tree, Many Worlds

> Exercise for **Chapter 17 — VFS: The Layer That Unifies Filesystems** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- observe how a mount temporarily hides the underlying directory contents;
- create a private view of the mount tree without administrative privileges;
- compare the same pathname from inside and outside a namespace;
- traverse /proc/PID/root to reach an isolated process's view when permissions allow it.

## Prerequisites

- A Linux host with Bash and the unshare, mount, and umount utilities.
- Unprivileged user namespaces enabled.
- /proc mounted and accessible for your own processes.
- No sudo privileges are required.

## Instructions

Run the complete demonstration with:

    solution/run.sh

The script creates a private scratch directory and starts the isolated process with exactly:

    unshare --user --map-root-user --mount --propagation private

1. Before the mount, the covered directory contains labcap17-original.txt. Inside the private namespace, mount a 4 MiB tmpfs over that directory:

       mount -t tmpfs -o size=4m,nosuid,nodev labcap17tmpfs DIRECTORY

   List the directory: the original file has not been deleted, but the new filesystem hides it. Create labcap17-inside-only.txt in the tmpfs, unmount it, and verify that the original file reappears while the tmpfs file disappears.

2. While tmpfs is mounted, inspect the same pathname from the outside process. The outside view must contain the original file and not the inside file: the mount did not propagate beyond the namespace. Also compare /proc/PID/mountinfo for the isolated process with the outside process's mountinfo, looking for labcap17tmpfs.

3. If /proc permissions allow it, traverse the isolated process's root:

       ls -la /proc/PID/root/SCRATCH_PATH/covered

   From this outside path you should see labcap17-inside-only.txt. /proc/PID/root does not merely expose the host disk; it resolves the path through the selected process's mount view. If a hidepid or ptrace policy denies access, record the skip without changing global permissions.

4. Record comparisons and explanations in start/observations.md. Never run mount manually over the real view of /tmp or a personal directory.

The exit handler unmounts tmpfs inside the namespace and removes the scratch directory. If the process is interrupted, destroying the namespace still discards its private mount.

## Definition of "done"

- [ ] You saw the original file before the mount, hidden during the mount, and visible again after umount.
- [ ] You verified that the file created in tmpfs is visible only from the isolated view.
- [ ] You confirmed through mountinfo that labcap17tmpfs belongs only to the private namespace.
- [ ] You reached the inside file through /proc/PID/root or documented the permission denial.
- [ ] You used no sudo command and mounted nothing in the host's real view.
- [ ] No lab process, mount, or scratch directory remains at the end.
