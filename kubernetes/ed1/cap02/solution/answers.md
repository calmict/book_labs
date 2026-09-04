# Chapter 2 - A container by hand, without Docker - answers

## The completed TODOs

TODO 3 (2.5) records the host hostname and the pid, uts, net and user namespace inodes.

TODO 1 (2.2, 2.3) adds these flags:

    --pid --fork --mount --mount-proc --uts --ipc --net

TODO 2 (2.2, 2.4, 2.5) sets hand-made-container as the hostname and records PID, interfaces and namespace inodes from inside. The complete implementation is solution/handmade.sh.

## Reflection answers

a. unshare asks the kernel for the separate views that form the isolation part of docker run. No second kernel is created.

b. chroot supplies a private filesystem root, but this small container still has no image management, layers, resource policy, runtime lifecycle, default security policy or orchestration.

c. A new PID namespace affects children. --fork creates the first child inside it, so that child receives PID 1.
