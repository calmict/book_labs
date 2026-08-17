# Observations

## Default policy and exceptions

All three filter base chains use policy drop. Loopback and established replies are allowed where needed, and the forward chain admits only new TCP traffic from labcap29in to port 8080 on labcap29out. A direct attempt to reach port 9090 times out.

## Packet path

The DNAT connection increments labcap29_forward_web while labcap29_input_seen remains at zero. Destination translation happens before the routing decision. Once the new destination is 10.29.2.2, the kernel routes the packet through labcap29out and therefore evaluates forward, not input.

## Address translation

The client connects to 10.29.1.1:18080. The server reports 10.29.2.2:8080 as the accepted socket's local endpoint. The conntrack tuple contains both views and supplies the reverse translation for reply packets.
