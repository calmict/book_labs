# Chapter 6 — Wire Two Network Namespaces by Hand (veth, a Bridge and a Ping)

> Exercise for **Chapter 6 — Linux Networking from the Ground Up** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- create network namespaces, virtual cables (veth) and a virtual switch (bridge), and wire them up the way a container runtime would;
- follow a ping across your switch and read the evidence it leaves behind (ARP table, bridge forwarding);
- recognise in docker0 the very same layout you just built by hand.

## Prerequisites

- Chapters 1-5 completed (chapter 2 above all: here the network namespace stops being a dead end and becomes a network).
- A Linux host with iproute2 (the ip command) and sudo privileges.
- Docker is only needed for the final comparison in step 6.

> 💡 **No sudo?** The whole lab also works as a regular user, inside a user
> namespace:
>
>     unshare -Urnm
>     mount -t tmpfs tmpfs /run
>
> and from there on, every command of the brief without sudo. Safety bonus:
> you work in a toy network completely separate from the real one — nothing
> can break. When you exit the shell everything vanishes by itself (you can
> skip step 7 too).

## Instructions

1. Create the two "computers" (network namespaces) and see where they live:

       sudo ip netns add blue
       sudo ip netns add red
       ip netns list
       ls /run/netns

   The files in /run/netns are handles onto the same namespace objects you met in chapter 2 under /proc/[pid]/ns.

2. Look inside a freshly born namespace:

       sudo ip netns exec blue ip addr

   Just one loopback, down: the same desolation you saw from the chapter 2 container — now you know where it comes from.

3. Build the switch (bridge) and the two cables (veth pairs): every cable has two ends, one goes into its namespace and the other into the switch:

       sudo ip link add br-lab type bridge
       sudo ip link set br-lab up
       sudo ip link add veth-blue type veth peer name veth-blue-br
       sudo ip link set veth-blue netns blue
       sudo ip link set veth-blue-br master br-lab up
       sudo ip link add veth-red type veth peer name veth-red-br
       sudo ip link set veth-red netns red
       sudo ip link set veth-red-br master br-lab up

4. Give each inner end an address and switch everything on:

       sudo ip netns exec blue ip addr add 10.42.0.2/24 dev veth-blue
       sudo ip netns exec blue ip link set veth-blue up
       sudo ip netns exec blue ip link set lo up
       sudo ip netns exec red ip addr add 10.42.0.3/24 dev veth-red
       sudo ip netns exec red ip link set veth-red up
       sudo ip netns exec red ip link set lo up

5. The moment of truth:

       sudo ip netns exec blue ping -c 3 10.42.0.3

   If the first packet gets lost it is not an error: it is ARP learning the addresses. Then collect the evidence of the journey — the neighbour's MAC learned by blue, and the ports on which the bridge learned to forward:

       sudo ip netns exec blue ip neigh
       sudo bridge fdb show br br-lab

6. The final déjà vu: look at Docker's network with the same glasses.

       ip addr show docker0
       docker run -d --name lab-cap06 alpine:3 sleep infinity
       ip link show master docker0

   A veth attached to docker0 has appeared: bridge plus veth cables, exactly the layout you just built, only with less readable names. Remove the container: docker rm -f lab-cap06.

   The three questions for answers.md: (a) why does a veth have TWO ends, and why does one live in the namespace and the other on the bridge? (b) describe the ping's journey (veth-blue → br-lab → veth-red and back) and explain what ip neigh and the bridge fdb tell you; (c) the blue namespace can ping red but not the internet: what is it missing? (think about default route and NAT — that is §6.2 of the manual).

7. Tear down the lab:

       sudo ip netns del blue
       sudo ip netns del red
       sudo ip link del br-lab

   (the veth ends disappear on their own: half of them lived in the deleted namespaces, and the other half dies when its pair partner dies)

## Definition of "done"

- [ ] The ping from blue to red gets replies across the bridge.
- [ ] ip neigh inside blue shows red's MAC, and the br-lab fdb shows on which ports it learned the addresses.
- [ ] You recognised the bridge+veth layout in docker0 (or you did everything in the rootless variant).
- [ ] answers.md answers the three questions.
- [ ] Namespaces and bridge removed, no orphan veth interfaces left (ip link | grep veth does not show yours).
