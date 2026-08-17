# Chapter 28 — Building a Network by Hand

> Exercise for **Chapter 28 — Interfaces, Addresses, Routing, and Sockets** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- create network namespaces and move the ends of a veth pair into them;
- configure addresses and verify connectivity between two isolated network stacks;
- build an Ethernet segment with a bridge and three endpoints;
- use ip route get to predict the interface and source address selected by the kernel.

## Prerequisites

- A Linux system with Bash, iproute2, bridge, and ping.
- Administrative privileges to create temporary namespaces, veth devices, and bridges.
- No existing interface whose name starts with labcap28.

## Instructions

1. Before creating any object, verify that the chosen names do not exist. Never reuse an object you find:

       ip link show labcap28a0
       ip link show labcap28b0
       ip link show labcap28br
       ip netns list

2. Create labcap28a and labcap28b, connect them with the labcap28a0 and labcap28b0 veth pair, assign 10.28.1.1/30 and 10.28.1.2/30, and bring the interfaces up. Ask the kernel which route it will use before sending a ping:

       sudo ip netns exec labcap28a ip route get 10.28.1.2
       sudo ip netns exec labcap28a ping -c 2 -W 1 10.28.1.2

   The expected result contains dev labcap28a0 and src 10.28.1.1.

3. Remove the direct link. Create labcap28c and labcap28fabric. Create the labcap28br bridge inside labcap28fabric. Connect each endpoint to the bridge with a veth pair whose name starts with labcap28. Configure the endpoints as 10.28.2.11/24, 10.28.2.12/24, and 10.28.2.13/24.

4. Inspect the bridge and its forwarding database, then query routing before generating traffic:

       sudo ip netns exec labcap28fabric bridge link show
       sudo ip netns exec labcap28fabric bridge fdb show br labcap28br
       sudo ip netns exec labcap28a ip route get 10.28.2.13
       sudo ip netns exec labcap28a ping -c 2 -W 1 10.28.2.13
       sudo ip netns exec labcap28c ping -c 2 -W 1 10.28.2.12

   Compare the ip route get prediction with the interface and source address actually used. This topology reproduces the segment that a container runtime creates automatically.

5. Run the automated solution as root. Deleting the namespaces also removes their bridges and veth devices; the script additionally checks for any host-side ends left behind:

       sudo ./solution/run.sh

## Definition of "done"

- [ ] The labcap28 names were checked before creation.
- [ ] labcap28a reaches labcap28b over the direct veth pair.
- [ ] Three endpoints reach one another through labcap28br.
- [ ] The decisions shown by ip route get match the connectivity tests.
- [ ] All namespaces, the bridge, and all labcap28 veth devices have been removed.
