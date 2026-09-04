#!/usr/bin/env bash
# Chapter 6 solution - build a disposable bridge and two network namespaces,
# then record ping, ARP, and forwarding evidence. Runs only in a toy user/net
# namespace created by run.sh; it never changes the host network.
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
ip link add br-lab type bridge
ip link set br-lab up
ip link add veth-blue type veth peer name veth-blue-br
ip link set veth-blue netns blue
ip link set veth-blue-br master br-lab up
ip link add veth-red type veth peer name veth-red-br
ip link set veth-red netns red
ip link set veth-red-br master br-lab up

ip netns exec blue ip addr add 10.42.0.2/24 dev veth-blue
ip netns exec blue ip link set veth-blue up
ip netns exec blue ip link set lo up
ip netns exec red ip addr add 10.42.0.3/24 dev veth-red
ip netns exec red ip link set lo up
if [ "${CAP06_RED_DOWN:-0}" != 1 ]; then
  ip netns exec red ip link set veth-red up
fi

ip netns exec blue ping -c 3 -W 1 10.42.0.3 > "$OUT/ping.txt"
ip netns exec blue ip neigh show 10.42.0.3 > "$OUT/neigh.txt"
bridge fdb show br br-lab > "$OUT/fdb.txt"
ip -o link show master br-lab > "$OUT/ports.txt"
