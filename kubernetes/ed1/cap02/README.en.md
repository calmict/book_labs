# Chapter 2 — A container by hand, without Docker

**Level:** Foundational

After observing two views in chapter 1, you build the illusion yourself using only Linux kernel tools.

## Objectives

- Create PID, mount, UTS, IPC, NET and USER namespaces with unshare (2.2, 2.3).
- Obtain PID 1, a private hostname and isolated networking (2.2, 2.4).
- Compare the inodes exposed by /proc/[pid]/ns (2.5).

## Prerequisites

- Linux with unshare, sh and permission to create unprivileged user namespaces.
- Chapter 1 completed. No sudo, Docker or Kubernetes cluster is required.

## The scenario

The start/ directory contains handmade.sh, which downloads an Alpine mini rootfs and opens only a USER namespace. Fill three gaps so unshare and chroot turn it into a small rootless container.

    cd kubernetes/ed1/cap02/start

### Phase 1 — The walls (2.2, 2.3 — TODO 1)

Add PID, mount, UTS, IPC and NET namespaces and remount /proc in the new view.

### Phase 2 — The inside evidence (2.2, 2.4, 2.5 — TODO 2)

Set the hostname and record PID, interfaces and namespace inodes from inside.

### Phase 3 — The comparison (2.5 — TODO 3)

Record the same inodes and hostname from the host, then run:

    cd ../solution
    ./run.sh

## "Done" criteria

- The shell is PID 1, the hostname is private and the network shows only loopback.
- The pid, uts, net and user inodes differ from the host values.
- run.sh prints OK 1..5 and ALL CHECKS PASSED.

## How it is verified

- OK 1 checks PID 1; OK 2 checks UTS isolation; OK 3 checks the private network.
- OK 4 compares the four namespace inodes.
- OK 5 removes the PID namespace and proves that the shell is no longer PID 1.

## Reflection questions

**a.** In what sense does unshare perform the conceptual work of docker run?

**b.** What does chroot provide, and what is still missing compared with a complete runtime?

**c.** Why is --fork required together with --pid?

## Cleanup

The processes end with the script; run.sh removes its temporary directory.

## Where it leads

Chapter 3 adds cgroup consumption limits to these visibility boundaries.
