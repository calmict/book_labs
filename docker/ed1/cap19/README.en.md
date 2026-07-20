# Chapter 19 — On the quay, and beyond the horizon

**Level:** Cloud Architect

Until now containers lived behind the switchboard: a private IP, NAT filtering
between them and the real network. Fine for most cases, but sometimes you need more:
for the container to appear on the physical network as a machine of its own, with its
own address and its own MAC, unmediated. That is the macvlan driver — the container
on the quay, no longer behind the glass. In this lab you give two containers a direct
address on a parent interface's network and verify that each has its own MAC and that
they talk to each other on the same segment. Then you look beyond the single host's
horizon: ipvlan (the variant that shares the MAC) and overlay (the network that spans
several hosts), the bridge toward orchestration.

## Objectives

- Give a container a direct address on a parent's network with macvlan (19.1).
- Verify that each container has its own MAC — an L2 identity of its own on the
  segment (19.1).
- Verify that two macvlan containers on the same parent reach each other at layer 2
  (19.1).
- Frame ipvlan (19.2) and overlay (19.3) and understand when they are needed (19.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- **A parent interface.** macvlan attaches to a real interface; to avoid touching the
  machine's NIC we use a dedicated dummy interface, created once with sudo
  (reversible). Before you start:

      sudo ip link add cap19dummy type dummy
      sudo ip link set cap19dummy up

  At the end of the chapter you remove it with: sudo ip link del cap19dummy
- Chapter 16 (network namespaces) and chapters 17-18 (the drivers): here you add the
  driver that puts the container directly on the physical segment.

## The scenario

In start/ you will find imacvlan.sh: a script that, given the parent cap19dummy,
should create a macvlan network, start two containers on it and measure their MAC and
reachability — but the three key operations are missing. You fill three gaps
(TODO 1..3). Throwaway network and containers, removed at the end; the real NIC and
the daemon are not touched.

Prepare the environment:

    cd docker/ed1/cap19/start

### Phase 1 — The macvlan network (19.1 — TODO 1)

Open start/imacvlan.sh and complete **TODO 1**: create a macvlan network on the
parent and start two containers, each with an IP on the parent's subnet. With macvlan
the container does not get a private IP behind NAT: it is addressed directly on the
segment.

    docker network create -d macvlan --subnet 192.168.190.0/24 -o parent="$PARENT" "$NET" >/dev/null
    docker run -d --name "$A" --network "$NET" --ip 192.168.190.10 busybox sleep 60 >/dev/null
    docker run -d --name "$B" --network "$NET" --ip 192.168.190.11 busybox sleep 60 >/dev/null

### Phase 2 — A MAC for each (19.1 — TODO 2)

Complete **TODO 2**: read the eth0 MAC of each container. Unlike the bridge, where
containers live behind the bridge's single MAC, here each has its own hardware
address — it appears as a distinct device on the segment.

    a_mac=$(docker exec "$A" cat /sys/class/net/eth0/address)
    b_mac=$(docker exec "$B" cat /sys/class/net/eth0/address)

### Phase 3 — On the same segment (19.1 — TODO 3)

Complete **TODO 3**: verify that the two containers reach each other by IP. They are
both on the parent's segment, adjacent at layer 2: they talk directly.

    reach=$(docker exec "$A" sh -c "ping -c1 -w2 192.168.190.11 >/dev/null 2>&1 && echo OK || echo FAIL")

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- imacvlan.sh creates the macvlan network and the two containers (TODO 1).
- It reads each container's MAC (TODO 2).
- It verifies L2 reachability between the two (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — direct address: the container has an IP on the parent's subnet
  (192.168.190.x), not a private IP behind NAT.
- **OK 2** — its own MAC: the two containers have distinct MACs — each an L2 identity
  of its own on the segment.
- **OK 3** — same segment: the two macvlan containers reach each other by IP (adjacent
  at layer 2).

## Reflection questions

**a.** With macvlan the container has its own MAC and an IP on the parent's network,
without NAT: it appears as a physical machine of its own on the LAN. What are the
benefits (integration with existing networks and appliances, no port mapping) and the
limits (the container usually cannot talk to its own host, the NIC needs promiscuous
mode, you consume real LAN addresses)?

**b.** ipvlan is the variant: instead of giving each container a new MAC, it shares
the parent's MAC and distinguishes by IP (L2 mode) or routes (L3 mode). Why is ipvlan
preferable to macvlan in certain environments — cloud, or switches with port security
that limit the MACs per port?

**c.** overlay is something else again: a network spanning several hosts (it
encapsulates traffic in VXLAN), and for that it needs shared state — swarm or an
orchestrator — which we did not enable here so as not to touch the daemon. How is this
the bridge toward the Kubernetes book, where the network model (one IP per pod, a flat
network between nodes) generalises exactly this idea?

## Cleanup

The script removes the two containers and the macvlan network (docker rm -f, docker
network rm, with a safety trap). The parent interface cap19dummy remains: having been
created with sudo, you remove it by hand when you are done:

    sudo ip link del cap19dummy

The daemon is never restarted and the real NIC is never touched.

## Where it leads

With this chapter Part 5 is complete: from the network namespace to bridges, to the
host/none drivers, to the container directly on the physical segment and the
multi-host horizon. **Part 6** changes level: no longer one container at a time but a
whole application. **Chapter 20** opens Docker Compose — designing multi-service
applications where the custom network, the service names and the volumes you learned
compose into a single file. For the command reference, see the volume's appendices.
