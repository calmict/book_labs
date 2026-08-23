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
network at all, and the bridge in between. Then you reproduce the two traps that
follow from it — the published port that host mode throws away, and the name that
does not resolve on the default bridge — and diagnose them.

## Objectives

- See that the host driver makes the container share the host's network namespace —
  no isolation (18.1).
- See that the none driver gives the container its own namespace but no eth0 — no
  connectivity (18.2).
- Compare with the default bridge: its own namespace and an eth0 — isolated but
  connected (18.4).
- Understand how to choose the driver and why host is powerful but delicate (18.3).
- Reproduce the first trap: in host mode publishing a port with -p is ignored, and
  two containers that want the same port collide (18.1).
- Reproduce the second: on the default bridge another container's name does not
  resolve, because the embedded DNS is not there (18.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 16 (network namespace) and 17 (bridge): here you see what happens when the
  network namespace is the host's, or when it is empty.

## The scenario

In start/ you will find idriver.sh: a script that starts a container with each driver
and should read what it gets — namespace, interfaces, and the behaviour in the two
traps — but the key reads are missing. You fill six gaps (TODO 1..6). The scenario
uses port 18080: if it is already taken on your machine, the test says so instead of
failing obscurely. Throwaway containers (--rm); no network is
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

### Phase 4 — The port that is not published (18.1 — TODO 4)

Complete **TODO 4**: start a container in host mode also asking to publish a port
with -p, then ask Docker what it published.

    hostmode_cid=$(docker run -d --network host -p "$PORT:80" busybox sleep 15 2>/dev/null)
    hostmode_ports=$(docker port "$hostmode_cid" | tr '\n' ' ')
    docker rm -f "$hostmode_cid" >/dev/null 2>&1

It published nothing, and that is not a bug: publishing a port means creating a NAT
rule that leads from the host to the container. In host mode there is no boundary to
cross — the container is already on the socket — so there is nothing to translate,
and -p is simply thrown away.

### Phase 5 — Two containers, one port (18.1 — TODO 5)

Complete **TODO 5**: this is the direct consequence. Put two host-mode containers to
listen on the same port: the first takes it, the second dies.

    first_cid=$(docker run -d --network host busybox nc -l -p "$PORT")
    sleep 1
    first_state=$(docker inspect -f '{{.State.Running}}' "$first_cid")
    second_cid=$(docker run -d --network host busybox nc -l -p "$PORT")
    sleep 1
    second_state=$(docker inspect -f '{{.State.Running}}' "$second_cid")
    second_log=$(docker logs "$second_cid" 2>&1 | tr -d '\n')
    docker rm -f "$first_cid" "$second_cid" >/dev/null 2>&1

On the bridge this would not happen: each container has its own stack and its own
port 80, and it is NAT that tells them apart from outside. With no isolation there
is nothing left to separate them, and ports go back to being a single resource of
the machine.

### Phase 6 — The name that does not resolve (18.4 — TODO 6)

Complete **TODO 6**: start a container with a name and try to reach it by name from
another container, both on the **default** bridge.

    docker run -d --name "$PROBE" busybox sleep 15 >/dev/null
    dns=$(docker run --rm busybox sh -c "ping -c1 -W1 $PROBE >/dev/null 2>&1 && echo RESOLVED || echo FAILED")
    cleanup_probe

It fails, and the diagnosis is the one from chapter 17: Docker's embedded DNS lives
on user-defined networks, not on the default bridge. On the default the addresses are
there, the names are not.

Once the six TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- idriver.sh reads the namespace of the host-driver container (TODO 1).
- It reads namespace and eth0 of the none-driver container (TODO 2).
- It reads namespace and eth0 of the default-bridge container (TODO 3).
- It reproduces the port ignored in host mode (TODO 4).
- It reproduces the port conflict between two host-mode containers (TODO 5).
- It reproduces the DNS failure on the default bridge (TODO 6).
- run.sh prints OK 1..6 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — host: the container shares the host's network namespace (same inode) —
  no network isolation.
- **OK 2** — none: the container has its own namespace (different from the host) but
  no eth0 — no connectivity.
- **OK 3** — bridge: the container has its own namespace and an eth0 — isolated but
  connected.
- **OK 4** — host: the port asked for with -p is not published, because there is no
  NAT to cross.
- **OK 5** — host: two containers cannot share the same port; the second dies saying
  the address is already in use.
- **OK 6** — default bridge: another container's name does not resolve, because the
  embedded DNS lives only on user-defined networks.

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

Nothing to tear down by hand: the reading containers are throwaway (--rm), the ones
started in the background for the two traps are removed right after the measurement —
and the probe container by a trap as well, if anything is interrupted. No network is
created. The busybox base image stays in cache (shared). The daemon is never
restarted.

## Where it leads

With this chapter you have the picture of the "home" drivers. Part 5 closes by
looking beyond the single host: **chapter 19** — at Cloud Architect level — covers
macvlan and ipvlan (giving the container an address on the physical network, as if it
were a machine of its own) and the overlay horizon (a network spanning multiple
hosts), the bridge toward orchestration and the Kubernetes book. For the command
reference, see the volume's appendices.
