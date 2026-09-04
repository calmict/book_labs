#!/usr/bin/env bash
# Chapter 6 start - wire two network namespaces through veth pairs and a bridge.
# Valid but incomplete; run it inside the user namespace prepared by run.sh.
set -euo pipefail

OUT=${1:?usage: network-lab.sh OUTPUT_DIR}
mkdir -p "$OUT"

cleanup() {
  ip netns del blue 2>/dev/null || true
  ip netns del red 2>/dev/null || true
  ip link del br-lab 2>/dev/null || true
}
trap cleanup EXIT
cleanup

ip netns add blue
ip netns add red

# TODO 1 (6.1): create br-lab and two veth pairs, move one end of each pair
# into its namespace, and attach the host-side ends to the bridge. This is the
# physical layout a container runtime builds.

# TODO 2 (6.1): assign 10.42.0.2/24 and 10.42.0.3/24 and bring both veth ends
# and loopback devices up. Addresses alone do not make a down link usable.

# TODO 3 (6.1): send the ping, then record blue's neighbour table and the
# bridge FDB in OUTPUT_DIR. These tables prove ARP resolution and MAC learning.
: > "$OUT/ping.txt"
: > "$OUT/neigh.txt"
: > "$OUT/fdb.txt"
