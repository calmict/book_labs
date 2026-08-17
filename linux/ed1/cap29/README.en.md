# Chapter 29 — A Minimal Firewall, with Proof of Where It Filters

> Exercise for **Chapter 29 — nftables and the Firewall** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- build a ruleset with a default drop policy and explicit exceptions;
- distinguish the input and forward paths using named counters;
- publish an internal service with DNAT;
- identify the address and port before and after translation.

## Prerequisites

- A Linux system with Bash, Python 3, iproute2, nftables, and conntrack-tools.
- Administrative privileges to create temporary namespaces and veth devices.
- Kernel support for forwarding, conntrack, nftables, and NAT.

## Instructions

1. Verify that labcap29, labcap29client, and labcap29server do not exist, then create them. Connect the client to the firewall on 10.29.1.0/24 and the server on 10.29.2.0/24. labcap29 must own 10.29.1.1 and 10.29.2.1; enable ip_forward only inside it.

2. Read start/labcap29.nft. The input, forward, and output chains have a drop policy. The only exceptions permit loopback, replies belonging to existing connections, and the internal TCP service on port 8080 when reached from the client side.

3. Show the empty labcap29 ruleset before loading the file, then show the same namespace's ruleset immediately afterward. Never omit ip netns exec labcap29 from an nft command:

       sudo ip netns exec labcap29 nft list ruleset
       sudo ip netns exec labcap29 nft -f start/labcap29.nft
       sudo ip netns exec labcap29 nft list ruleset

4. Start the service in labcap29server on 10.29.2.2:8080. From the client, connect to 10.29.1.1:18080, the address published on the client-facing side. Compare the named counters:

       sudo ip netns exec labcap29 nft list counter inet labcap29filter labcap29_input_seen
       sudo ip netns exec labcap29 nft list counter inet labcap29filter labcap29_forward_web

   The forward counter must increase while the input counter remains at zero: after DNAT, the routing decision forwards the packet to the server rather than delivering it to a local firewall process.

5. Inspect the server log and the conntrack entry inside the firewall namespace:

       sudo ip netns exec labcap29 conntrack -L -p tcp

   The client uses 10.29.1.1:18080, while the server accepts the connection on 10.29.2.2:8080. This difference makes the destination rewrite visible. Also try 10.29.2.2:9090 and verify that the drop policy blocks it.

6. Run the automated solution as root. Do not run nft commands in the machine's initial namespace. Deleting labcap29 also removes its isolated ruleset:

       sudo ./solution/run.sh

## Definition of "done"

- [ ] The ruleset has a drop policy and exposes only the required exceptions.
- [ ] The published connection increments labcap29_forward_web but not labcap29_input_seen.
- [ ] The service is reachable through 10.29.1.1:18080 and the server records 10.29.2.2:8080 as its local destination.
- [ ] An unauthorized connection to 10.29.2.2:9090 fails.
- [ ] All three namespaces, veth devices, processes, and the isolated ruleset have been removed.
