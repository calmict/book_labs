# Chapter 24 — The right keys, not all of them

**Level:** Cloud Architect

In chapter 23 you saw who root is; now you see that root is not one block. The powers
of root are split by the kernel into many separate keys — the capabilities: the right
to open raw sockets, to bind low ports, to mount filesystems, to change owners. A
container almost never needs all of them. The principle is that of a well-made safe:
give each one only the key it needs. And above the capabilities are two more layers —
seccomp, which filters syscalls, and AppArmor or SELinux, which confine what a process
may touch. Defence in depth. In this lab you touch the capabilities first-hand: drop
everything, and the same operation fails; grant back the right key, and it resumes —
without returning all the others. Then you repeat the exercise on a sharper key, the
one mounting a filesystem needs; you check that seccomp is a barrier of its own — it
refuses a syscall at identical capabilities — and you measure what --privileged really
changes.

## Objectives

- See that root is not monolithic: its powers are separate capabilities (24.1).
- Drop all capabilities with --cap-drop ALL and watch an operation fail (24.1).
- Grant back only the needed capability with --cap-add: least privilege (24.1).
- Repeat the exercise on a dangerous capability: mounting a filesystem needs
  SYS_ADMIN, which the default set does not include (24.1).
- Check that seccomp is an independent barrier: it filters syscalls at identical
  capabilities (24.2).
- Measure what --privileged really grants, reading the effective set before and after
  (24.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 23 (the privilege model): here you restrict not who you are, but what you
  can do.

## The scenario

In start/ you will find icapabilities.sh: a script that should try the same operation
(a ping, which needs the NET_RAW capability) with three different capability sets, then
repeat it on a more dangerous capability, question seccomp and read what --privileged
does — but the attempts are missing. You fill six gaps (TODO 1..6). Throwaway
containers (--rm); no host path is ever mounted into them, the daemon is not
touched.

Prepare the environment:

    cd docker/ed1/cap24/start

### Phase 1 — With the default keys (24.1 — TODO 1)

Open start/icapabilities.sh and complete **TODO 1**: run a ping in a default container.
It works: among the capabilities Docker grants by default is NET_RAW, needed for ping's
raw socket.

    default=$(docker run --rm busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

### Phase 2 — With all keys dropped (24.1 — TODO 2)

Complete **TODO 2**: run the same ping but with --cap-drop ALL. The process is still
root, but without NET_RAW it cannot open the raw socket: it fails.

    dropall=$(docker run --rm --cap-drop ALL busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

### Phase 3 — Only the right key (24.1 — TODO 3)

Complete **TODO 3**: drop everything and grant back only NET_RAW. The ping resumes, but
the container has exactly one capability, not all of them — least privilege.

    dropadd=$(docker run --rm --cap-drop ALL --cap-add NET_RAW busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

### Phase 4 — A sharper key (24.1 — TODO 4)

Complete **TODO 4**: repeat the exercise on an operation more dangerous than a ping.
Mounting a filesystem needs SYS_ADMIN, which the default set does not include: the
container is root and is refused all the same. Then grant back that one key.

    mount_default=$(docker run --rm busybox sh -c 'mkdir -p /mnt/t; mount -t tmpfs none /mnt/t >/dev/null 2>&1 && echo MOUNTED || echo DENIED')
    mount_added=$(docker run --rm --cap-add SYS_ADMIN busybox sh -c 'mkdir -p /mnt/t; mount -t tmpfs none /mnt/t >/dev/null 2>&1 && echo MOUNTED || echo DENIED')

SYS_ADMIN is not a key like the others: it is the one that opens the most doors, which
is why granting it is nearly the same as granting --privileged.

### Phase 5 — The second barrier: seccomp (24.2 — TODO 5)

Complete **TODO 5**: read the container's seccomp mode, then try the same syscall with
and without the default profile. The capabilities do not change between the two runs:
only the filter does.

    seccomp_mode=$(docker run --rm busybox sh -c 'grep "^Seccomp:" /proc/self/status | tr -d "\t" | cut -d: -f2')
    unshare_default=$(docker run --rm busybox sh -c 'unshare -U true >/dev/null 2>&1 && echo ALLOWED || echo BLOCKED')
    unshare_unconfined=$(docker run --rm --security-opt seccomp=unconfined busybox sh -c 'unshare -U true >/dev/null 2>&1 && echo ALLOWED || echo BLOCKED')

Mode 2 means a filter is loaded. And the syscall that creates a USER namespace is
refused with the default profile and goes through without it: it is seccomp stopping
it, not the capabilities. Two independent barriers — that is what defence in depth
means.

### Phase 6 — What --privileged really grants (24.4 — TODO 6)

Complete **TODO 6**: read the effective capability set in a normal container and in a
privileged one, and retry the mount.

    caps_default=$(docker run --rm busybox sh -c 'grep "^CapEff:" /proc/self/status | tr -d "\t" | cut -d: -f2')
    caps_privileged=$(docker run --rm --privileged busybox sh -c 'grep "^CapEff:" /proc/self/status | tr -d "\t" | cut -d: -f2')
    mount_privileged=$(docker run --rm --privileged busybox sh -c 'mkdir -p /mnt/t; mount -t tmpfs none /mnt/t >/dev/null 2>&1 && echo MOUNTED || echo DENIED')

The mask goes from a reduced set to every bit lit, and the mount succeeds without your
asking for anything. It is the exact opposite of least privilege: instead of handing
over the key that is needed, --privileged hands over the whole ring. The two
privileged containers in this phase do nothing but read their own status and mount a
tmpfs inside themselves: no host path is mounted, nothing on the machine is touched.

Once the six TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- icapabilities.sh tries the ping with the default capabilities (TODO 1).
- It retries it with --cap-drop ALL (TODO 2).
- It retries it with --cap-drop ALL --cap-add NET_RAW (TODO 3).
- It tries the mount without and with SYS_ADMIN (TODO 4).
- It questions seccomp and tries the same syscall with and without the profile
  (TODO 5).
- It reads the capability mask with and without --privileged (TODO 6).
- run.sh prints OK 1..6 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — with the default capabilities the ping works (NET_RAW is granted).
- **OK 2** — with --cap-drop ALL the ping fails: no NET_RAW, no raw socket, even as
  root.
- **OK 3** — with --cap-drop ALL --cap-add NET_RAW the ping resumes: the container was
  given only the key it needs.
- **OK 4** — mounting a filesystem is denied with the default set and succeeds once
  SYS_ADMIN alone is granted back: the same principle on a far more dangerous key.
- **OK 5** — seccomp: a filter is loaded (mode 2) and refuses the syscall on its own —
  unshare is blocked with the default profile and allowed without it, at identical
  capabilities.
- **OK 6** — --privileged: the effective set goes from the reduced one to every bit
  lit, and the mount succeeds without any capability having been asked for.

## Reflection questions

**a.** root is not monolithic: the kernel splits its powers into separate capabilities
(NET_RAW for raw sockets, NET_BIND_SERVICE for low ports, SYS_ADMIN for mounting, and
many more). Why is --cap-drop ALL followed by a targeted --cap-add the purest form of
least privilege, and why does Docker already drop a good many from the container by
default?

**b.** seccomp is a second layer: a profile that filters which syscalls a container may
invoke, blocking dangerous ones (like keyctl, or ptrace against other processes)
regardless of capabilities. Why is it complementary to capabilities rather than
redundant? And why is turning it off with --security-opt seccomp=unconfined a choice to
avoid, except for deliberate debugging?

**c.** AppArmor (Debian/Ubuntu) and SELinux (RHEL/Fedora — this machine's) are mandatory
access controls (MAC): they confine which files and paths a process may touch,
regardless of uid and capabilities. Why are they a third layer of defence in depth, and
how do they combine with capabilities and seccomp to reduce a container's overall
attack surface?

## Cleanup

Nothing to tear down by hand: all the containers are throwaway (--rm), the two
privileged ones included — they mount no host path and disappear with the command. The
busybox base image stays in cache. The daemon is never restarted.

## Where it leads

You restricted a container's privileges on three levels. But security is not only
prevention: when something goes wrong, you must see it. **Chapter 25** opens the theme
of observability — container logs, logging drivers, metrics — to know what a service is
really doing in production. For the reference, see the volume's appendices.
