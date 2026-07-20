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
without returning all the others.

## Objectives

- See that root is not monolithic: its powers are separate capabilities (24.1).
- Drop all capabilities with --cap-drop ALL and watch an operation fail (24.2).
- Grant back only the needed capability with --cap-add: least privilege (24.2).
- Frame seccomp (24.3) and AppArmor/SELinux (24.4) as additional layers.

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 23 (the privilege model): here you restrict not who you are, but what you
  can do.

## The scenario

In start/ you will find icapabilities.sh: a script that should try the same operation
(a ping, which needs the NET_RAW capability) with three different capability sets, but
the three attempts are missing. You fill three gaps (TODO 1..3). Throwaway containers
(--rm); the daemon is not touched.

Prepare the environment:

    cd docker/ed1/cap24/start

### Phase 1 — With the default keys (24.1 — TODO 1)

Open start/icapabilities.sh and complete **TODO 1**: run a ping in a default container.
It works: among the capabilities Docker grants by default is NET_RAW, needed for ping's
raw socket.

    default=$(docker run --rm busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

### Phase 2 — With all keys dropped (24.2 — TODO 2)

Complete **TODO 2**: run the same ping but with --cap-drop ALL. The process is still
root, but without NET_RAW it cannot open the raw socket: it fails.

    dropall=$(docker run --rm --cap-drop ALL busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

### Phase 3 — Only the right key (24.2 — TODO 3)

Complete **TODO 3**: drop everything and grant back only NET_RAW. The ping resumes, but
the container has exactly one capability, not all of them — least privilege.

    dropadd=$(docker run --rm --cap-drop ALL --cap-add NET_RAW busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- icapabilities.sh tries the ping with the default capabilities (TODO 1).
- It retries it with --cap-drop ALL (TODO 2).
- It retries it with --cap-drop ALL --cap-add NET_RAW (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — with the default capabilities the ping works (NET_RAW is granted).
- **OK 2** — with --cap-drop ALL the ping fails: no NET_RAW, no raw socket, even as
  root.
- **OK 3** — with --cap-drop ALL --cap-add NET_RAW the ping resumes: the container was
  given only the key it needs.

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

Nothing to tear down by hand: all the containers are throwaway (--rm). The busybox base
image stays in cache. The daemon is never restarted.

## Where it leads

You restricted a container's privileges on three levels. But security is not only
prevention: when something goes wrong, you must see it. **Chapter 25** opens the theme
of observability — container logs, logging drivers, metrics — to know what a service is
really doing in production. For the reference, see the volume's appendices.
