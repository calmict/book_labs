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

**TODO 4 (19.2) — the hairpin limit:**

    a_to_host=$(docker exec "$A" sh -c "ping -c1 -w2 192.168.190.1 >/dev/null 2>&1 && echo OK || echo FAIL")
    host_to_a=$(ping -c1 -w2 192.168.190.10 >/dev/null 2>&1 && echo OK || echo FAIL)

Both come back FAIL, and that is the expected result. Asserting a failure is only
worth something with a control alongside it, and there are two here. The sibling ping
of TODO 3 succeeds over the same parent, so the segment carries traffic. And run.sh
refuses to start unless the host actually holds 192.168.190.1/24 on the parent, so the
host is on the segment and a missing route cannot be mistaken for the limit.

What blocks the path is the macvlan design: a child and the parent it hangs from are
isolated from each other, whichever direction you try. The standard workaround is to
give the host a macvlan child of its own and let the address live there, so that both
ends are children rather than parent-and-child. Verified in an ephemeral namespace,
where the same three pings behave the same way and start working after the shim
appears:

    sudo ip addr del 192.168.190.1/24 dev cap19dummy
    sudo ip link add cap19shim link cap19dummy type macvlan mode bridge
    sudo ip addr add 192.168.190.1/24 dev cap19shim
    sudo ip link set cap19shim up

It stays out of the automatic test because it needs root on the host, and this lab
asks for sudo only once, to create the parent.

**TODO 5 (19.2) — the other driver:**

The macvlan side has to come down first. A parent interface accepts one kind of child
at a time: with a macvlan port already attached, creating the ipvlan network succeeds
but the first container fails to start with "failed to create the ipvlan port: device
or resource busy". That error is itself worth meeting once.

    docker rm -f "$A" "$B" >/dev/null
    docker network rm "$NET" >/dev/null
    docker network create -d ipvlan --subnet 192.168.191.0/24 -o parent="$PARENT" -o ipvlan_mode=l2 "$IPVNET" >/dev/null
    parent_mac=$(cat "/sys/class/net/$PARENT/address")
    c_mac=$(docker exec "$C" cat /sys/class/net/eth0/address)
    d_mac=$(docker exec "$D" cat /sys/class/net/eth0/address)

The reading is unambiguous: both ipvlan containers report the parent's own MAC, while
the two macvlan containers reported one each. They still reach each other, so what
changes is not connectivity but L2 identity — the single fact on which the choice
between the two drivers rests when the network polices MAC addresses per port.

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
