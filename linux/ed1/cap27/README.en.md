# Chapter 27 — Following a Packet

> Exercise for **Chapter 27 — The TCP/IP Stack Inside the Kernel** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- read the per-CPU distribution of network-related interrupts;
- trigger and identify drops caused by a full UDP receive buffer;
- distinguish socket drops from drops recorded on an interface;
- fill an isolated conntrack table and recognize its counter and application-level symptom.

## Prerequisites

- A Linux system with Bash, Python 3, iproute2, procps, nftables, and conntrack-tools.
- Administrative privileges to create the labcap27 namespace.
- The nf_conntrack kernel module available.

## Instructions

1. Read /proc/interrupts without modifying it. Find rows associated with network interfaces and compare the counters under CPU0, CPU1, and subsequent CPUs. If the machine exposes no named network interrupts, record that result rather than inventing one:

       head -n 1 /proc/interrupts
       grep -Ei 'eth|enp|eno|ens|virtio|mlx|ixgbe|network' /proc/interrupts

2. Create the namespace and bring loopback up. All traffic in the following steps must remain inside labcap27:

       sudo ip netns add labcap27
       sudo ip -n labcap27 link set lo up

3. Start socket_pressure.py as a receiver in the namespace. It requests a small UDP buffer and waits before reading. During that pause, send a burst with the same program in send mode. Compare Udp RcvbufErrors in /proc/net/snmp, the d field shown by ss -u -a -n -m, and loopback RX dropped before and after:

       sudo ip netns exec labcap27 python3 start/socket_pressure.py receive 27270 &
       sleep 0.1
       sudo ip netns exec labcap27 python3 start/socket_pressure.py send 27270 50000
       sudo ip netns exec labcap27 ss -u -a -n -m
       sudo ip -n labcap27 -s link show lo
       wait

   RcvbufErrors and the socket counter identify a full receive queue. Interface RX dropped describes a drop at a different layer of the system.

4. Enable tracking with a harmless nft table and an output chain whose policy is accept, set nf_conntrack_max to 128 only inside the namespace, and generate more distinct UDP flows than the limit. Compare nf_conntrack_count, conntrack -C, and conntrack -S before and after. A rising insert_failed counter and fewer received datagrams than sent datagrams are the full-table symptom.

5. Run the automated solution as root. The script refuses to reuse an existing namespace and always deletes its own namespace at the end:

       sudo ./solution/run.sh

## Definition of "done"

- [ ] You recorded per-CPU counters for at least one network interrupt source, or documented that the environment exposes none.
- [ ] You increased Udp RcvbufErrors and socket drops without incorrectly attributing them to interface RX dropped.
- [ ] You observed nf_conntrack_count near its limit and insert_failed above its initial value.
- [ ] You connected conntrack pressure to loss visible at the receiver.
- [ ] labcap27, its nft table, and all test processes have been removed.
