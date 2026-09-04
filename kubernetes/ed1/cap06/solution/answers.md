# Chapter 6 - Wire two network namespaces by hand - answers

## The completed TODOs

TODO 1 (6.1) creates br-lab and two veth pairs. One end enters blue or red;
the other remains beside the bridge and becomes one of its ports.

TODO 2 (6.1) assigns 10.42.0.2/24 and 10.42.0.3/24 and brings both veth and
loopback interfaces up. A configured address on a down interface cannot carry
the ping.

TODO 3 (6.1) sends the ping and saves ip neigh and bridge fdb output. The two
tables turn successful connectivity into evidence of ARP and MAC learning.

## Reflection answers

a. A veth is a virtual cable: a packet entering one end exits the other. One
end must live inside the airtight namespace; its peer stays outside and plugs
into the bridge so that traffic can cross the boundary.

b. Blue resolves red's IP through ARP. Frames cross veth-blue, emerge from
veth-blue-br, traverse br-lab, enter veth-red-br, and emerge on veth-red. The
neighbour table remembers the IP-to-MAC mapping; the FDB remembers the bridge
port associated with each source MAC.

c. Blue has neither a default route through a gateway nor source NAT on that
gateway. The local subnet works directly, but traffic for the internet has no
next hop and its private source address would not be routable back.
