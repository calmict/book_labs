# Chapter 16 — Answers

## The completed TODOs

**TODO 1 (16.1) — the container's own network namespace:**

    c1_ns=$(docker exec "$C1" readlink /proc/self/ns/net)

**TODO 2 (16.4) — the eth0 IP of each container:**

    c1_ip=$(docker exec "$C1" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')
    c2_ip=$(docker exec "$C2" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')

**TODO 3 (16.2) — the veth indices:**

    c1_ifindex=$(docker exec "$C1" cat /sys/class/net/eth0/ifindex)
    c1_iflink=$(docker exec "$C1" cat /sys/class/net/eth0/iflink)

**TODO 4 (16.1+16.2) — the hand-built cable and bridge:**

The solution enters an unprivileged user, mount and network namespace, creates the
container network namespace and joins its eth0 to br-cap16 with a veth pair. The
bridge is the gateway for the private 10.16.0.0/24 subnet:

    ip netns add "$NS_CONTAINER"
    ip link add "$BRIDGE" type bridge
    ip addr add 10.16.0.1/24 dev "$BRIDGE"
    ip link add "$VETH_BRIDGE" type veth peer name "$VETH_CONTAINER"
    ip link set "$VETH_BRIDGE" master "$BRIDGE"
    ip link set "$VETH_CONTAINER" netns "$NS_CONTAINER"
    ip -n "$NS_CONTAINER" link set "$VETH_CONTAINER" name eth0
    ip -n "$NS_CONTAINER" addr add 10.16.0.2/24 dev eth0

**TODO 5 (16.3) — the simulated outside and NAT:**

The second namespace represents a different, external subnet. Forwarding and the
MASQUERADE rule exist only in the throwaway network namespace:

    sysctl -q -w net.ipv4.ip_forward=1
    iptables -t nat -A POSTROUTING -s 10.16.0.0/24 -o "$VETH_EXTERNAL" -j MASQUERADE

**TODO 6 — proof and comparison:**

A ping from the container to 192.0.2.2 must succeed. The solution then reads the
POSTROUTING packet counter and requires it to be greater than zero: the rule was not
merely present, it processed real traffic. run.sh reads ip addr show docker0 and
bridge link on the host only to compare the topology. It deliberately does not read
Docker's host iptables rules, because an unprivileged user cannot do so.

## Reflection questions

**a. Why does the container's eth0 not appear on the host, and what does the
isolation mean?**

A network namespace is a private copy of the whole networking stack: its own set of
interfaces, its own routing table, its own iptables rules, its own sockets. When
Docker starts a container it creates a fresh network namespace and moves the
container's eth0 into it, so that interface exists only there — the host, in its own
namespace, never lists it. Two containers each get their own namespace, so neither
sees the other's interfaces, addresses or listening ports: they are as separate, at
the network level, as two different machines. It is the same namespace mechanism as
chapter 2 (PID, mount, UTS...), applied to networking: isolate by giving each a
private instance of the resource.

**b. Why are ifindex and iflink different, and what is the peer?**

A veth pair is created as two linked interfaces — think of a cable with a plug at
each end. Docker puts one end inside the container (named eth0) and leaves the other
on the host, where it attaches it to the docker0 bridge. Each interface has its own
index within its own namespace (ifindex), but a veth end also records the index of
the interface at the other end of the cable (iflink) — and since the peer lives in a
different namespace, that number is different. So ifindex is "who I am here" and
iflink is "who I am wired to over there". If that cable were unplugged (the host-side
veth deleted), the container's eth0 would go down and it would lose all connectivity
beyond its own loopback — the container would still run, but be network-isolated.

**c. How does docker0 set up the next chapters?**

docker0 is a virtual switch in the host's namespace; every container's host-side veth
plugs into it, so containers on the same bridge are on the same L2 segment and can
reach each other by IP directly. To leave for the Internet, their private addresses
are translated to the host's with a NAT masquerade rule the daemon installs, so
replies find their way back. This is the default bridge — shared, unnamed, IP-only.
Chapter 17 builds on it by creating custom bridges, where Docker adds an embedded DNS
so containers resolve one another by name and where separate bridges isolate groups
of containers; chapter 18 steps sideways to the other drivers — host (no namespace of
its own, the container shares the host's stack) and none (a namespace with no cable
at all).
