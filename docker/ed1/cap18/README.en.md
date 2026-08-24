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
- Demonstrate that host directly occupies host ports and ignores -p (18.1).
- Qualitatively compare host and bridge paths to the same service, measuring
  latency without using it as an assertion (18.3).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 16 (network namespace) and 17 (bridge): here you see what happens when the
  network namespace is the host's, or when it is empty.

## The scenario

In start/ you will find drivers.sh: a script that starts a container with each driver
and should read what it gets — namespace and interfaces — and compare ports and
paths, but the five key parts are missing. You fill five gaps (TODO 1..5).
Throwaway containers (--rm); no network is created, the daemon is not touched nor
restarted. For a few seconds three small ephemeral HTTP servers listen on high host
ports: the script picks free ports before starting and a trap always releases them,
even if the test is interrupted halfway.

Prepare the environment:

    cd docker/ed1/cap18/start

### Phase 1 — Plugged into the socket: host driver (18.1 — TODO 1)

Open start/drivers.sh and complete **TODO 1**: read the network namespace of a
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

### Phase 4 — There is only one host port (18.1 — TODO 4)

The script already starts three throwaway servers for you: one in host mode on the
chosen port (with a -p that host mode will ignore), one in host mode on a free port,
one on the default bridge publishing a port. Complete **TODO 4**: try the same
listener again in host mode on the port already taken — it must fail with address
already in use — and read the control on the free port, which is running instead.
Then compare what docker port says in the two cases: no mapping in host mode, a
mapping on the bridge.

    set +e
    conflict_output=$(docker run --rm --network host -v "$OUT:/www:ro" busybox httpd -f -p "$PORT" -h /www 2>&1)
    conflict_status=$?
    set -e
    free_running=$(docker inspect -f '{{.State.Running}}' "$FREE_SERVER")
    host_port_output=$(docker port "$HOST_SERVER")
    bridge_port_output=$(docker port "$BRIDGE_SERVER" 80/tcp)

### Phase 5 — Two paths to the same service (18.3 — TODO 5)

Complete **TODO 5**: query the same host server first from a host-mode container
through 127.0.0.1, then from a bridge container. On the bridge, 127.0.0.1 is the
container's loopback and must fail; the gateway address, read from the default
route, must work.

    host_loopback=$(docker run --rm --network host busybox wget -q -O /dev/null "http://127.0.0.1:$PORT" && echo yes || echo no)
    bridge_loopback=$(docker run --rm busybox wget -q -T 1 -O /dev/null "http://127.0.0.1:$PORT" 2>/dev/null && echo yes || echo no)
    bridge_gateway=$(docker run --rm busybox sh -c 'gateway=$(ip route | awk '\''/default/ { print $3; exit }'\''); wget -q -O /dev/null "http://$gateway:'"$PORT"'" && echo yes || echo no')

Finally, time one hundred sequential requests over both paths, measuring them
INSIDE the container with time, so that the startup of docker run stays out of the
figure. The two times are only printed, never asserted — and they almost always come
out comparable: that is exactly what 18.3 says, the NAT overhead is negligible for
the vast majority of workloads. The real difference between the two drivers is not
speed, it is which paths exist.

Once the five TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- drivers.sh reads the namespace of the host-driver container (TODO 1).
- It reads namespace and eth0 of the none-driver container (TODO 2).
- It reads namespace and eth0 of the default-bridge container (TODO 3).
- It demonstrates the host-port conflict and ignored -p, with their positive
  controls (TODO 4).
- It compares host-loopback, bridge-loopback, and bridge-gateway paths to the same
  service and prints both latency measurements (TODO 5).
- run.sh prints OK 1..5 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — host: the container shares the host's network namespace (same inode) —
  no network isolation.
- **OK 2** — none: the container has its own namespace (different from the host) but
  no eth0 — no connectivity.
- **OK 3** — bridge: the container has its own namespace and an eth0 — isolated but
  connected.
- **OK 4** — host: the same port conflicts and a free port works; -p is ignored in
  host mode but produces a mapping on the bridge.
- **OK 5** — same service: host loopback works; bridge loopback fails and the bridge
  gateway works. The times for the two paths are only printed.

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

Nothing to tear down by hand: a trap stops the HTTP server and the other cap18
containers even if the test is interrupted, releasing the high ports; the
containers are throwaway (--rm) and no network is created. The busybox base image
stays in cache (shared). The daemon is never restarted.

## Where it leads

With this chapter you have the picture of the "home" drivers. Part 5 closes by
looking beyond the single host: **chapter 19** — at Cloud Architect level — covers
macvlan and ipvlan (giving the container an address on the physical network, as if it
were a machine of its own) and the overlay horizon (a network spanning multiple
hosts), the bridge toward orchestration and the Kubernetes book. For the command
reference, see the volume's appendices.
