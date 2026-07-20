# Chapter 18 — Answers

## The completed TODOs

**TODO 1 (18.1) — host driver shares the host's network namespace:**

    host_driver_ns=$(docker run --rm --network host busybox readlink /proc/self/ns/net)

**TODO 2 (18.2) — none driver: own namespace, no eth0:**

    none_ns=$(docker run --rm --network none busybox readlink /proc/self/ns/net)
    none_eth0=$(docker run --rm --network none busybox sh -c '[ -e /sys/class/net/eth0 ] && echo yes || echo no')

**TODO 3 (18.4) — default bridge: own namespace and an eth0:**

    bridge_ns=$(docker run --rm busybox readlink /proc/self/ns/net)
    bridge_eth0=$(docker run --rm busybox sh -c '[ -e /sys/class/net/eth0 ] && echo yes || echo no')

## Reflection questions

**a. Benefits and risks of the host driver, and when to use it.**

With --network host the container is not given a new network namespace: it runs
directly in the host's, so it sees the host's interfaces and any port it opens is
open on the host, with no -p mapping and no NAT in the path. The benefits are
performance (no bridge, no address translation, no extra hop) and simplicity for
things that need to see the real network — a high-throughput proxy, a monitoring
agent that must read host interfaces. The risks are the flip side of the same coin:
no isolation at all, so the container can bind or clash with any host port, can reach
anything the host can, and a compromise gives the attacker the host's network
position. Use it deliberately, for a specific need, not as a convenience.

**b. What is a container with no network for, and how to add one later?**

--network none gives the container a network namespace with only loopback: it can
talk to itself and to nothing else. That is exactly right for work that needs no
network — a batch job that reads and writes a mounted volume, a CPU-bound computation,
a data transformation — where removing the network removes a whole class of risk and
attack surface: a process with no route out cannot exfiltrate, cannot be reached, and
cannot be tricked into calling home. If it later needs a network, you do not have to
recreate it: docker network connect attaches it to a network on the fly, giving it a
fresh interface, so "none now, network later" is a valid pattern.

**c. How to choose, and why host needs care.**

Bridge is the default because it is the balanced choice: each container isolated in
its own namespace, yet connected through the bridge and reachable via published
ports. Reach for host only when you need the host's exact network and can accept the
loss of isolation; reach for none when the container should have no network at all.
The power of host is that there is no separate network namespace to cross — which is
also precisely its danger: everything the container does on the network, it does as
the host, so in production it turns a container escape at the network layer into no
escape at all, because there was never a wall to climb.
