# Chapter 6 — Wire two network namespaces by hand

**Level:** Foundational

The namespaces from chapter 2 were sealed rooms. Now you lay the cables: two veth pairs and a bridge
turn two isolated network views into a small network without ever changing the host network.

## Objectives

- Create namespaces, veth pairs, and a bridge as a runtime would (6.1).
- Follow a ping and read ARP resolution in the neighbour table (6.1).
- Read the forwarding learned by the bridge in its FDB (6.1).

## Prerequisites

- A Linux host with Docker, unshare, mount, ip, bridge, and ping.
- Unprivileged user namespaces enabled; sudo is not required.
- The test mounts a private /run directory and does not change the host network.

## The scenario

In start/network-lab.sh blue and red are born, but the switch, wiring, and evidence are missing. Run the
script inside the toy network prepared by the verifier.

    cd kubernetes/ed1/cap06/start

### Phase 1 — The switch and cables (6.1 — TODO 1)

Create br-lab and two veth pairs. Move veth-blue and veth-red into their namespaces; attach peers
veth-blue-br and veth-red-br to the bridge and bring them up.

### Phase 2 — Addresses and links (6.1 — TODO 2)

Assign 10.42.0.2/24 to blue and 10.42.0.3/24 to red. Bring up both interfaces and loopbacks: an address
on a down link cannot carry traffic.

### Phase 3 — Traces of the journey (6.1 — TODO 3)

Send three echo requests from blue to red. Save the result, blue's ip neigh output, and br-lab's bridge
fdb output. Then start a temporary Docker container and recognise the same bridge-plus-veth layout on
docker0. Run the check:

    cd ../solution
    ./run.sh

## Definition of "done"

- The ping crosses the bridge without final packet loss.
- The neighbour table and FDB contain red's MAC.
- Both outside peers are br-lab ports.
- run.sh prints OK 1..5 and ALL CHECKS PASSED.

## How it is verified

- OK 1 checks the ping from blue to red.
- OK 2 correlates the MAC learned through ARP with the bridge FDB.
- OK 3 checks br-lab's peers and recognises the same bridge-plus-veth layout on docker0.
- OK 4 is the gate: with veth-red left down, the ping must fail.
- OK 5 confirms that no toy-network object escaped into the host.

## Reflection questions

**a.** Why does a veth have two ends, one in the namespace and one on the bridge?

**b.** What path does the ping take, and what do the neighbour table and FDB remember?

**c.** Why can blue reach red but not the internet? What roles do a default route and NAT play (6.2)?

## Cleanup

Every run lives in a throwaway user and network namespace. The inner trap deletes namespaces and the
bridge; when unshare exits, the entire toy network disappears in any case.

## Where it leads

You wired by hand what a runtime repeats for every container. The next part takes these mechanisms into
the cluster, where Kubernetes delegates the wiring to network plugins.
