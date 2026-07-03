# Chapter 6 — Answers (model solution)

## The ping across the bridge

    3 packets transmitted, 3 received, 0% packet loss

(a lost first packet is fine too: that is ARP resolving the neighbour before
the first echo can leave)

## The evidence

    # ip neigh, inside blue
    10.42.0.3 dev veth-blue lladdr 36:0b:89:46:1e:a7 REACHABLE

    # bridge fdb show br br-lab (learned entries)
    22:1c:b0:77:ff:d4 dev veth-blue-br master br-lab
    36:0b:89:46:1e:a7 dev veth-red-br  master br-lab

(blue learned red's MAC via ARP; the bridge learned, from the traffic itself,
which port leads to which MAC — the same MAC appears on the veth-red-br port)

## The déjà vu on docker0

    # ip link show master docker0, with one container running
    vethf3a2b1c@if5: <BROADCAST,MULTICAST,UP,LOWER_UP> ... master docker0 ...

(a veth end attached to the docker0 bridge: the exact layout of br-lab, with
generated names)

## The three questions

**a. Why does a veth have TWO ends, and why does one live in the namespace
and the other on the bridge?**

Because a network interface can only exist in one namespace at a time, and a
namespace is airtight: to get packets across the wall you need a pipe with a
mouth on each side. A veth pair is that pipe — whatever enters one end comes
out of the other. So one end is moved inside the container's namespace (and
gets the IP address), while the other stays outside and is enslaved to the
bridge, which plays the role of the office switch every cable plugs into.

**b. Describe the ping's journey and explain what ip neigh and the bridge
fdb tell you.**

Blue wants to reach 10.42.0.3, an address on its own subnet, so it first
asks "who has 10.42.0.3?" (ARP) out of veth-blue. The request exits the
other end of the cable on veth-blue-br, the bridge floods it, red answers
with its MAC. From then on the echo requests travel veth-blue → bridge →
veth-red, and the replies come back the same way. ip neigh inside blue is
the memory of that ARP exchange (red's MAC, REACHABLE); the bridge fdb is
the switch's own notebook: by watching source MACs it learned which port
leads to which address, so it can forward instead of flooding.

**c. The blue namespace can ping red but not the internet: what is it
missing?**

Two things. First, a route: blue only knows the 10.42.0.0/24 subnet, it has
no default gateway, so any packet for the outside world has nowhere to go —
the bridge would need an IP on the host side acting as gateway. Second, NAT:
10.42.0.2 is a private address the internet cannot answer to, so the host
must rewrite the source address (masquerade) on the way out and undo it on
the way back. Route plus NAT rules are exactly the iptables story of §6.2 —
and precisely what Docker sets up for you around docker0 without asking.
