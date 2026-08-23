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

**TODO 4 (18.1) — the port that host mode throws away:**

    hostmode_cid=$(docker run -d --network host -p "$PORT:80" busybox sleep 15 2>/dev/null)
    hostmode_ports=$(docker port "$hostmode_cid" | tr '\n' ' ')
    docker rm -f "$hostmode_cid" >/dev/null 2>&1

docker port prints nothing. Publishing means writing a DNAT rule from a host port to
a container port; in host mode the container is already on the host's stack, there is
no boundary and therefore no rule to write. Docker accepts the flag and discards it,
which is why the mistake is easy to make: nothing fails, the service is simply
reachable on whatever port it actually binds, not on the one you asked for.

**TODO 5 (18.1) — two containers, one port:**

    first_cid=$(docker run -d --network host busybox nc -l -p "$PORT")
    sleep 1
    first_state=$(docker inspect -f '{{.State.Running}}' "$first_cid")
    second_cid=$(docker run -d --network host busybox nc -l -p "$PORT")
    sleep 1
    second_state=$(docker inspect -f '{{.State.Running}}' "$second_cid")
    second_log=$(docker logs "$second_cid" 2>&1 | tr -d '\n')
    docker rm -f "$first_cid" "$second_cid" >/dev/null 2>&1

The second container dies with "nc: bind: Address already in use". On a bridge the
two would coexist happily, each with its own port 80 inside its own stack, and NAT
would give them different ports outside. Host mode removes that separation: the port
space is the machine's, and two services that want the same number cannot both run.
It is the price of the speed - no NAT to cross also means no NAT to hide behind.

**TODO 6 (18.4) — the name that does not resolve:**

    docker run -d --name "$PROBE" busybox sleep 15 >/dev/null
    dns=$(docker run --rm busybox sh -c "ping -c1 -W1 $PROBE >/dev/null 2>&1 && echo RESOLVED || echo FAILED")
    cleanup_probe

FAILED, and the reason is not a broken network: the containers can reach each other
by IP perfectly well. Docker's embedded DNS resolver, which turns a container name
into its address, is attached to user-defined networks only; the default bridge never
had it. The diagnosis to remember is the shape of the failure - a name that does not
resolve while the address works is almost always the default bridge, and the cure is
a user-defined network (chapter 17), not a DNS setting.

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
