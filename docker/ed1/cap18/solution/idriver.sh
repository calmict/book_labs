#!/usr/bin/env bash
# cap18 solution - "plugged in or unplugged": the network drivers side by side.
# The host driver makes the container share the host's network namespace (same
# inode, no isolation); the none driver gives it its own namespace but no eth0 (no
# connectivity); the default bridge gives it its own namespace and an eth0
# (isolated but connected). Throwaway containers (--rm), no network created, no
# restart, no privileges. The host container only reads.
set -euo pipefail

OUT="${1:?usage: idriver.sh OUTPUT_DIR}"
mkdir -p "$OUT"

host_ns=$(readlink /proc/self/ns/net)

# TODO 1 (18.1): host driver - the container shares the host's network namespace.
host_driver_ns=$(docker run --rm --network host busybox readlink /proc/self/ns/net)

# TODO 2 (18.2): none driver - own namespace, but no eth0 (no connectivity).
none_ns=$(docker run --rm --network none busybox readlink /proc/self/ns/net)
none_eth0=$(docker run --rm --network none busybox sh -c '[ -e /sys/class/net/eth0 ] && echo yes || echo no')

# TODO 3 (18.4): default bridge - own namespace and an eth0 (isolated but connected).
bridge_ns=$(docker run --rm busybox readlink /proc/self/ns/net)
bridge_eth0=$(docker run --rm busybox sh -c '[ -e /sys/class/net/eth0 ] && echo yes || echo no')

{
  echo "host_ns=$host_ns"
  echo "host_driver_ns=$host_driver_ns"
  echo "none_ns=$none_ns"
  echo "none_eth0=$none_eth0"
  echo "bridge_ns=$bridge_ns"
  echo "bridge_eth0=$bridge_eth0"
} > "$OUT/drivers.txt"
