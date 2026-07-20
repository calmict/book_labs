# Chapter 19 — Answers

## The completed TODOs

**TODO 1 (19.1) — the macvlan network and two containers:**

    docker network create -d macvlan --subnet 192.168.190.0/24 -o parent="$PARENT" "$NET" >/dev/null
    docker run -d --name "$A" --network "$NET" --ip 192.168.190.10 busybox sleep 60 >/dev/null
    docker run -d --name "$B" --network "$NET" --ip 192.168.190.11 busybox sleep 60 >/dev/null

**TODO 2 (19.1) — each container's own MAC:**

    a_mac=$(docker exec "$A" cat /sys/class/net/eth0/address)
    b_mac=$(docker exec "$B" cat /sys/class/net/eth0/address)

**TODO 3 (19.1) — L2 reachability on the segment:**

    reach=$(docker exec "$A" sh -c "ping -c1 -w2 192.168.190.11 >/dev/null 2>&1 && echo OK || echo FAIL")

## Reflection questions

**a. Benefits and limits of macvlan.**

With macvlan Docker creates, for each container, a sub-interface on the parent with
its own MAC address, and gives it an IP on the parent's subnet. To the rest of the
network the container is indistinguishable from a physical machine: no NAT, no port
mapping, its services are reachable at its own address on the real segment. That is
the benefit — it integrates cleanly with existing networks, DHCP, monitoring,
appliances that expect real hosts. The limits are the flip side: by design a macvlan
container cannot talk to its own host over macvlan (the parent excludes itself); the
NIC must allow multiple MACs, i.e. promiscuous mode, which some environments forbid;
and every container consumes a real address on the LAN, which does not scale to
thousands the way a private NAT'd bridge does.

**b. Why ipvlan instead of macvlan?**

ipvlan solves the "too many MACs" problem. Where macvlan gives every container a new
MAC on the parent, ipvlan makes them all share the parent's single MAC and
distinguishes them by IP: in L2 mode they still sit on the parent's segment, in L3
mode the host routes for them. This matters in environments that police MAC
addresses: many cloud networks and enterprise switches with port security allow only
one (or a few) MAC per port and will drop frames from unexpected ones — exactly what
macvlan produces. There ipvlan works where macvlan is blocked, at the cost of the
per-container MAC identity.

**c. Why was overlay not run, and how does it bridge to Kubernetes?**

An overlay network spans multiple hosts: it wraps container traffic in VXLAN so that
containers on different machines share one virtual L2/L3 network. To coordinate which
host holds which container and to distribute the encapsulation state, it needs a
control plane — Docker's built-in one requires swarm mode, an external one a key-value
store. Enabling swarm changes the daemon's state, so this lab did not run it. But the
idea it embodies — a flat network across many hosts, where every workload has an
address and reaches every other regardless of which machine it runs on — is exactly
the Kubernetes network model: one IP per pod, pods on any node reaching pods on any
other node without NAT, realised by a CNI plugin doing the same overlay (or routed)
work. Understanding overlay here is understanding the shape of cluster networking you
meet in full in the Kubernetes book.
