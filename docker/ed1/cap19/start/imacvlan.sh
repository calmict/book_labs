#!/usr/bin/env bash
# cap19 start - the macvlan driver, to complete. Given the parent cap19dummy
# (created once with sudo - see README), the three key operations are missing.
# Three gaps (TODO 1..3): the network + containers, the MAC reads and the L2
# reachability check are empty and the test fails. Throwaway network and containers.
set -euo pipefail

OUT="${1:?usage: imacvlan.sh OUTPUT_DIR}"
mkdir -p "$OUT"
PARENT="cap19dummy"
NET="cap19net-$$"
A="cap19a-$$"
B="cap19b-$$"
cleanup() {
  docker rm -f "$A" "$B" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# the dummy parent must exist (created once with sudo - see README)
if ! ip -br link show "$PARENT" >/dev/null 2>&1; then
  echo "ERROR: parent interface '$PARENT' not found. Create it first:" >&2
  echo "  sudo ip link add $PARENT type dummy && sudo ip link set $PARENT up" >&2
  exit 1
fi

# TODO 1 (19.1): create a macvlan network on the parent and start two containers,
#   each with a fixed IP on the parent's subnet:
#     docker network create -d macvlan --subnet 192.168.190.0/24 -o parent="$PARENT" "$NET" >/dev/null
#     docker run -d --name "$A" --network "$NET" --ip 192.168.190.10 busybox sleep 60 >/dev/null
#     docker run -d --name "$B" --network "$NET" --ip 192.168.190.11 busybox sleep 60 >/dev/null

# TODO 2 (19.1): read each container's own IP and MAC:
#     a_ip=$(docker exec "$A" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')
#     a_mac=$(docker exec "$A" cat /sys/class/net/eth0/address)
#     b_mac=$(docker exec "$B" cat /sys/class/net/eth0/address)
a_ip=""
a_mac=""
b_mac=""

# TODO 3 (19.1): check L2 reachability between the two containers:
#     reach=$(docker exec "$A" sh -c "ping -c1 -w2 192.168.190.11 >/dev/null 2>&1 && echo OK || echo FAIL")
reach=""

{
  echo "a_ip=$a_ip"
  echo "a_mac=$a_mac"
  echo "b_mac=$b_mac"
  echo "reach=$reach"
} > "$OUT/mac.txt"
