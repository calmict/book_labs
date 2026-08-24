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

**TODO 4 (18.1) — host-port conflict and ignored publishing** (the three servers
are already started by the script; these are the reads):

    set +e
    conflict_output=$(docker run --rm --network host -v "$OUT:/www:ro" busybox httpd -f -p "$PORT" -h /www 2>&1)
    conflict_status=$?
    set -e
    free_running=$(docker inspect -f '{{.State.Running}}' "$FREE_SERVER")
    host_port_output=$(docker port "$HOST_SERVER")
    bridge_port_output=$(docker port "$BRIDGE_SERVER" 80/tcp)

**TODO 5 (18.3) — host and bridge paths to the same service:**

    host_loopback=$(docker run --rm --network host busybox wget -q -O /dev/null "http://127.0.0.1:$PORT" && echo yes || echo no)
    bridge_loopback=$(docker run --rm busybox wget -q -T 1 -O /dev/null "http://127.0.0.1:$PORT" 2>/dev/null && echo yes || echo no)
    bridge_gateway=$(docker run --rm busybox sh -c 'gateway=$(ip route | awk '\''/default/ { print $3; exit }'\''); wget -q -O /dev/null "http://$gateway:'"$PORT"'" && echo yes || echo no')

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

The new checks make that trade-off concrete. A host-mode listener owns the actual
host port, so another identical listener collides; -p has no separate namespace to
publish from and is therefore ignored. A bridge container cannot use its own
127.0.0.1 to reach the host service: it must cross its gateway and the host's NAT
path. That extra mechanism is the real difference between the two drivers.
It is not, however, a difference you can feel: timed inside the container, one
hundred sequential requests take practically the same time on both paths, which is
what 18.3 says in prose — the NAT overhead is negligible for the vast majority of
workloads. The exercise therefore prints the two figures and asserts neither.
