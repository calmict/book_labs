#!/usr/bin/env bash
# cap18 solution - "plugged in or unplugged": the network drivers side by side.
# The host driver makes the container share the host's network namespace (same
# inode, no isolation); the none driver gives it its own namespace but no eth0 (no
# connectivity); the default bridge gives it its own namespace and an eth0
# (isolated but connected). Then it reproduces the two traps of the chapter: in
# host mode a published port is discarded, and two containers that want the same
# port collide because no NAT separates them; and on the default bridge the name
# of another container does not resolve. Throwaway containers, no network created,
# no restart, no privileges. The host container only reads.
set -euo pipefail

OUT="${1:?usage: idriver.sh OUTPUT_DIR}"
mkdir -p "$OUT"
PORT=18080                     # an unprivileged port, freed at the end of each step
PROBE="cap18-probe-$$"
cleanup_probe() { docker rm -f "$PROBE" >/dev/null 2>&1 || true; }
trap cleanup_probe EXIT

host_ns=$(readlink /proc/self/ns/net)

# TODO 1 (18.1): host driver - the container shares the host's network namespace.
host_driver_ns=$(docker run --rm --network host busybox readlink /proc/self/ns/net)

# TODO 2 (18.2): none driver - own namespace, but no eth0 (no connectivity).
none_ns=$(docker run --rm --network none busybox readlink /proc/self/ns/net)
none_eth0=$(docker run --rm --network none busybox sh -c '[ -e /sys/class/net/eth0 ] && echo yes || echo no')

# TODO 3 (18.4): default bridge - own namespace and an eth0 (isolated but connected).
bridge_ns=$(docker run --rm busybox readlink /proc/self/ns/net)
bridge_eth0=$(docker run --rm busybox sh -c '[ -e /sys/class/net/eth0 ] && echo yes || echo no')

# TODO 4 (18.1): in host mode there is no NAT, so a published port is discarded.
hostmode_cid=$(docker run -d --network host -p "$PORT:80" busybox sleep 15 2>/dev/null)
hostmode_ports=$(docker port "$hostmode_cid" | tr '\n' ' ')
docker rm -f "$hostmode_cid" >/dev/null 2>&1

# TODO 5 (18.1): the trap that follows from it - two containers, the same port.
first_cid=$(docker run -d --network host busybox nc -l -p "$PORT")
sleep 1
first_state=$(docker inspect -f '{{.State.Running}}' "$first_cid")
second_cid=$(docker run -d --network host busybox nc -l -p "$PORT")
sleep 1
second_state=$(docker inspect -f '{{.State.Running}}' "$second_cid")
second_log=$(docker logs "$second_cid" 2>&1 | tr -d '\n')
docker rm -f "$first_cid" "$second_cid" >/dev/null 2>&1

# TODO 6 (18.4): on the DEFAULT bridge the name of another container is not resolved.
docker run -d --name "$PROBE" busybox sleep 15 >/dev/null
dns=$(docker run --rm busybox sh -c "ping -c1 -W1 $PROBE >/dev/null 2>&1 && echo RESOLVED || echo FAILED")
cleanup_probe

{
  echo "host_ns=$host_ns"
  echo "host_driver_ns=$host_driver_ns"
  echo "none_ns=$none_ns"
  echo "none_eth0=$none_eth0"
  echo "bridge_ns=$bridge_ns"
  echo "bridge_eth0=$bridge_eth0"
  echo "hostmode_ports=$hostmode_ports"
  echo "first_state=$first_state"
  echo "second_state=$second_state"
  echo "second_log=$second_log"
  echo "dns=$dns"
} > "$OUT/drivers.txt"
