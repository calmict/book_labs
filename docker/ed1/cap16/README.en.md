# Chapter 16 — The cable and the switchboard

**Level:** Advanced

So far each container was an island of processes and of data; now you discover it is
also an island of network. Part 5 opens the labyrinths of networking, and the first
truth is that "giving a container a network" is not magic: Docker uses the same Linux
kernel building blocks. Every container gets its own network namespace — a network
stack all of its own, with its interfaces, its IP, its routing table — and is joined
to the world by a virtual cable, the veth pair: one end inside the container (eth0),
the other on the host, attached to the shared switchboard, the docker0 bridge. In
this lab you first inspect it on two real containers, then rebuild it by hand in an
isolated environment, add NAT towards a simulated external network, and finally
compare your own rule with the one Docker really wrote on the host.

## Objectives

- See that a container has its own network namespace, different from the host's
  (16.1).
- Recognise that each container has its own eth0 and its own address, distinct from
  the others (16.4).
- Understand that eth0 is one end of a veth pair: its peer is on the other side, on
  the host (16.2).
- Connect it all to the docker0 bridge as the shared switchboard (16.3).
- Build namespaces, veth and a bridge by hand without real privileges.
- Apply a MASQUERADE rule and prove it with end-to-end traffic to a simulated
  external network.
- Compare the hand-built topology with Docker's real bridge, read-only.
- Read the NAT rules Docker writes on the host, from a throwaway container holding
  NET_ADMIN alone, and recognise in them the rule you wrote by hand.

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 2 (namespaces): here you meet the network one, the network namespace.
- The unshare, ip, bridge, iptables, ping, sysctl, mount and umount commands.
- Network access on the first run: the test builds a minimal image (alpine plus the
  iptables package) to read the host's rules. From the second run on, the layer cache
  is enough.

## The scenario

In start/ you will find irete.sh: a script that starts two containers and should read
their network stack — namespace, address, cable — but the three key reads are
missing. You fill three gaps (TODO 1..3). The two containers run at the same time (so
each holds its own address) and are removed at the end; the default bridge is used,
with none other created or touched; the daemon is not touched.

You will also find ilcablaggio.sh in start/. TODO 4..6 rebuild the complete path in
an ephemeral user and network namespace: no interface or rule is created in the
host's real network. The external network is simulated locally, so the proof does
not depend on the reader's Internet access. TODO 7 goes back to irete.sh and closes
the circle: it reads the rules Docker really wrote, to compare them with yours.

The two halves ask for different things, and the brief follows. In Phases 1-3 and 7
you read and interpret: the exact line is written below, because the work is in
understanding what those numbers say, not in guessing the name of a file under /sys.
In Phases 4-6 you build, and there the line is not given: inside ilcablaggio.sh you
find the operations in order and the commands in play, while the arguments are yours
to write. It is by laying the bricks one after another that the chapter's claim shows
itself — a container's network is not magic.

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

### Phase 4 — Hand-built wiring (16.1+16.2 — TODO 4)

In start/ilcablaggio.sh create the container namespace, the br-cap16 bridge and a
veth pair. Move one end into the namespace, rename it eth0, assign 10.16.0.2/24 and
attach the other end to the bridge at 10.16.0.1/24. Bring interfaces and loopback up
and add the container's default route.

### Phase 5 — A controlled outside world (16.3 — TODO 5)

Create a second namespace connected to the isolated router on 192.0.2.0/24. Enable
IPv4 forwarding only inside the ephemeral environment and add a POSTROUTING
MASQUERADE rule scoped to source 10.16.0.0/24 and the external interface. Do not use
the Internet or write rules on the real host.

### Phase 6 — Proof and comparison (TODO 6)

Send one ping from 10.16.0.2 to 192.0.2.2. Record veth bridge membership and the
MASQUERADE rule counter after the traffic: it must be greater than zero. The test
also observes docker0 and bridge link on the host read-only, to compare bridge, veth
and private subnet.

### Phase 7 — The rules Docker really writes (16.3 — TODO 7)

Go back to start/irete.sh and fill in TODO 7. The host's NAT rules are not readable
without privileges: borrow them instead of granting yourself any. A throwaway
container enters the host's network namespace holding NET_ADMIN alone, reads the
POSTROUTING chain and disappears; the host is not touched and no rule is written.
Extract the default bridge's subnet and the outgoing interface of the MASQUERADE rule
that covers it: it is the very rule you wrote by hand in Phase 5, on another subnet.

Once the seven TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- irete.sh reads the container's network namespace (TODO 1).
- It reads the eth0 IP of both containers (TODO 2).
- It reads the veth indices (ifindex and iflink) (TODO 3).
- ilcablaggio.sh builds namespaces, veth and a bridge inside unshare -Urnm (TODO 4).
- Traffic reaches the simulated external network through MASQUERADE (TODO 5).
- The structure is compared with docker0 without changing the real network (TODO 6).
- irete.sh reads the MASQUERADE rule Docker wrote for its own bridge (TODO 7).
- run.sh prints OK 1..7 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — its own network namespace: the container's network namespace inode is
  different from the host's.
- **OK 2** — its own address: the two containers have two distinct IPs on the bridge,
  each its own stack.
- **OK 3** — veth pair: eth0's local index and its peer's index differ — eth0 is one
  end of a cable whose other end is on the host.
- **OK 4** — hand-built wiring: the namespace's eth0 is connected by veth to the
  private br-cap16 bridge.
- **OK 5** — end-to-end NAT: the ping reaches the external namespace and increments
  the counter of the MASQUERADE rule it actually crossed.
- **OK 6** — Docker comparison: docker0 is visible read-only and presents the same
  conceptual model of bridge, veth and private subnet.
- **OK 7** — the same rule, one subnet apart: the host's POSTROUTING holds a
  MASQUERADE for the Docker bridge subnet, shaped exactly like the one written by
  hand for 10.16.0.0/24.

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
rm -f, plus a safety trap). The second script explicitly removes namespaces, bridge,
veth and its temporary mount with a trap; all wiring lives inside an ephemeral user,
mount and network namespace anyway. docker0 is only observed, and the container that
reads the host's rules runs with --rm and writes nothing: the image carrying it is
removed by the trap at the end. The busybox and alpine base images stay in cache and
the daemon is never restarted.

## Where it leads

You saw the mechanism: namespace, cable, switchboard. **Chapter 17** goes into the
bridge as a network: the difference between the default bridge and a custom bridge —
why on a bridge you define containers resolve one another by name, and how one
network is isolated from another. For the command reference, see the volume's
appendices.
