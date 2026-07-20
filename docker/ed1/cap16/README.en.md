# Chapter 16 — The cable and the switchboard

**Level:** Advanced

So far each container was an island of processes and of data; now you discover it is
also an island of network. Part 5 opens the labyrinths of networking, and the first
truth is that "giving a container a network" is not magic: Docker uses the same Linux
kernel building blocks. Every container gets its own network namespace — a network
stack all of its own, with its interfaces, its IP, its routing table — and is joined
to the world by a virtual cable, the veth pair: one end inside the container (eth0),
the other on the host, attached to the shared switchboard, the docker0 bridge. In
this lab you verify it first-hand: two containers, two stacks, two addresses, each
with its own cable.

## Objectives

- See that a container has its own network namespace, different from the host's
  (16.1).
- Recognise that each container has its own eth0 and its own address, distinct from
  the others (16.4).
- Understand that eth0 is one end of a veth pair: its peer is on the other side, on
  the host (16.2).
- Connect it all to the docker0 bridge as the shared switchboard (16.3).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 2 (namespaces): here you meet the network one, the network namespace.

## The scenario

In start/ you will find irete.sh: a script that starts two containers and should read
their network stack — namespace, address, cable — but the three key reads are
missing. You fill three gaps (TODO 1..3). The two containers run at the same time (so
each holds its own address) and are removed at the end; the default bridge is used,
with none other created or touched; the daemon is not touched.

Prepare the environment:

    cd docker/ed1/cap16/start

### Phase 1 — A network stack of its own (16.1 — TODO 1)

Open start/irete.sh and complete **TODO 1**: read the first container's network
namespace (the inode of /proc/self/ns/net). Compared with the host's, it is
different: the container does not share the machine's network stack, it has one of
its own.

    c1_ns=$(docker exec "$C1" readlink /proc/self/ns/net)

### Phase 2 — An address for each (16.4 — TODO 2)

Complete **TODO 2**: read the eth0 IP of both containers. Running together on the
same bridge, they receive two different addresses — proof that each stack is
independent.

    c1_ip=$(docker exec "$C1" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')
    c2_ip=$(docker exec "$C2" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')

### Phase 3 — The virtual cable: veth (16.2 — TODO 3)

Complete **TODO 3**: eth0 is one end of a veth pair. Read the local index (ifindex)
and the peer's (iflink): they differ, because the cable's other end is in another
network — on the host, attached to docker0.

    c1_ifindex=$(docker exec "$C1" cat /sys/class/net/eth0/ifindex)
    c1_iflink=$(docker exec "$C1" cat /sys/class/net/eth0/iflink)

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- irete.sh reads the container's network namespace (TODO 1).
- It reads the eth0 IP of both containers (TODO 2).
- It reads the veth indices (ifindex and iflink) (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — its own network namespace: the container's network namespace inode is
  different from the host's.
- **OK 2** — its own address: the two containers have two distinct IPs on the bridge,
  each its own stack.
- **OK 3** — veth pair: eth0's local index and its peer's index differ — eth0 is one
  end of a cable whose other end is on the host.

## Reflection questions

**a.** A network namespace gives the container a complete network stack: interfaces,
routing table, rules. Why does the container's eth0 not appear among the host's
interfaces, and what does it mean that two containers do not see each other's stacks?
Connect the answer to the namespaces of chapter 2.

**b.** A veth pair is like a cable with two ends: write at one, it comes out the
other. Why are eth0's ifindex and iflink different numbers, and what does the peer on
"the other side", on the host, attached to docker0, represent? What would happen to
the container if that cable were unplugged?

**c.** The docker0 bridge is the switchboard: containers on the same bridge talk to
one another, and to reach the Internet the traffic is masqueraded (NAT masquerade)
with the host's address. How does this set up chapters 17 (default and custom
bridges) and 18 (host, none and choosing the driver)?

## Cleanup

Nothing to tear down by hand: the two containers are removed by the script (docker
rm -f, plus a safety trap) at the end; only the default bridge is used, never created
nor removed. The busybox base image stays in cache. The daemon is never restarted.

## Where it leads

You saw the mechanism: namespace, cable, switchboard. **Chapter 17** goes into the
bridge as a network: the difference between the default bridge and a custom bridge —
why on a bridge you define containers resolve one another by name, and how one
network is isolated from another. For the command reference, see the volume's
appendices.
