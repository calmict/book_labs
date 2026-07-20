# Chapter 18 — Plugged in or unplugged

**Level:** Advanced

Default bridge, custom bridge: so far every container had its own network stack,
isolated and connected. But it is not the only way. There are two extremes, and
choosing them is a design decision. On one side the host driver: the container has no
network of its own, it is plugged straight into the host's socket — sharing its
stack, its interfaces, its ports. No isolation, no NAT, maximum speed, maximum
exposure. On the other side the none driver: the container has its own namespace but
is unplugged — only loopback, no cable to the world. In this lab you touch the three
drivers side by side and see what changes: who shares the host's stack, who has no
network at all, and the bridge in between.

## Objectives

- See that the host driver makes the container share the host's network namespace —
  no isolation (18.1).
- See that the none driver gives the container its own namespace but no eth0 — no
  connectivity (18.2).
- Compare with the default bridge: its own namespace and an eth0 — isolated but
  connected (18.4).
- Understand how to choose the driver and why host is powerful but delicate (18.3).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 16 (network namespace) and 17 (bridge): here you see what happens when the
  network namespace is the host's, or when it is empty.

## The scenario

In start/ you will find idriver.sh: a script that starts a container with each driver
and should read what it gets — namespace and interfaces — but the three key reads are
missing. You fill three gaps (TODO 1..3). Throwaway containers (--rm); no network is
created, the daemon is not touched nor restarted. The host container only reads: it
opens no ports, changes nothing.

Prepare the environment:

    cd docker/ed1/cap18/start

### Phase 1 — Plugged into the socket: host driver (18.1 — TODO 1)

Open start/idriver.sh and complete **TODO 1**: read the network namespace of a
container started with --network host. It is the same as the host's: the container
has no stack of its own, it uses the machine's.

    host_driver_ns=$(docker run --rm --network host busybox readlink /proc/self/ns/net)

### Phase 2 — Unplugged: none driver (18.2 — TODO 2)

Complete **TODO 2**: start a container with --network none and read its namespace and
whether it has an eth0. It has a namespace all its own (different from the host) but
no eth0: only loopback, no way to the world.

    none_ns=$(docker run --rm --network none busybox readlink /proc/self/ns/net)
    none_eth0=$(docker run --rm --network none busybox sh -c '[ -e /sys/class/net/eth0 ] && echo yes || echo no')

### Phase 3 — In between: the bridge (18.4 — TODO 3)

Complete **TODO 3**: start a container with the default bridge and read its namespace
and eth0. Its own namespace (isolated from the host) and an eth0 (connected): the
middle way.

    bridge_ns=$(docker run --rm busybox readlink /proc/self/ns/net)
    bridge_eth0=$(docker run --rm busybox sh -c '[ -e /sys/class/net/eth0 ] && echo yes || echo no')

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- idriver.sh reads the namespace of the host-driver container (TODO 1).
- It reads namespace and eth0 of the none-driver container (TODO 2).
- It reads namespace and eth0 of the default-bridge container (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — host: the container shares the host's network namespace (same inode) —
  no network isolation.
- **OK 2** — none: the container has its own namespace (different from the host) but
  no eth0 — no connectivity.
- **OK 3** — bridge: the container has its own namespace and an eth0 — isolated but
  connected.

## Reflection questions

**a.** With the host driver the container shares the host's network stack: its ports
open directly on the host, without -p and without NAT. What are the benefits
(performance, no translation) and the risks (no isolation, port conflicts, a
compromised service has the host's network)? When would you really use it?

**b.** With the none driver the container has a network namespace but no interface to
the world, only loopback. What is a container with no network for — think of a batch
job processing a volume, or of reducing the attack surface to the minimum. And how
could you add a network to it later, if needed?

**c.** Three drivers, three trade-offs: bridge (isolated and connected, the default),
host (fast but exposed), none (no network). How do you choose, and why is the power of
the host driver — no separate network namespace — exactly what makes it something to
handle with care in production?

## Cleanup

Nothing to tear down by hand: all the containers are throwaway (--rm) and no network
is created. The busybox base image stays in cache (shared). The daemon is never
restarted.

## Where it leads

With this chapter you have the picture of the "home" drivers. Part 5 closes by
looking beyond the single host: **chapter 19** — at Cloud Architect level — covers
macvlan and ipvlan (giving the container an address on the physical network, as if it
were a machine of its own) and the overlay horizon (a network spanning multiple
hosts), the bridge toward orchestration and the Kubernetes book. For the command
reference, see the volume's appendices.
