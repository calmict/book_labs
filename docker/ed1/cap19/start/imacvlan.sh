#!/usr/bin/env bash
# cap19 start - the macvlan driver, to complete. Given the parent cap19dummy
# (created once with sudo - see README), the three key operations are missing.
# Five gaps (TODO 1..5): the network + containers, the MAC reads, the L2
# reachability check, the hairpin measurement and the ipvlan comparison are empty
# and the test fails. Throwaway networks and containers.
set -euo pipefail

OUT="${1:?usage: imacvlan.sh OUTPUT_DIR}"
mkdir -p "$OUT"
PARENT="cap19dummy"
NET="cap19net-$$"
IPVNET="cap19ipv-$$"
A="cap19a-$$"
B="cap19b-$$"
C="cap19c-$$"
D="cap19d-$$"
cleanup() {
  docker rm -f "$A" "$B" "$C" "$D" >/dev/null 2>&1 || true
  docker network rm "$NET" "$IPVNET" >/dev/null 2>&1 || true
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

# TODO 4 (19.2): the hairpin limit. The sibling ping above is the control - the
# segment carries traffic. Measure the two directions that do not work: from the
# container towards the host address on the parent, and from the host towards the
# container:
#     a_to_host=$(docker exec "$A" sh -c "ping -c1 -w2 192.168.190.1 >/dev/null 2>&1 && echo OK || echo FAIL")
#     host_to_a=$(ping -c1 -w2 192.168.190.10 >/dev/null 2>&1 && echo OK || echo FAIL)
a_to_host=""
host_to_a=""

# TODO 5 (19.2): the other driver. Take the macvlan side down first - a parent
# accepts one kind of child at a time - then create an ipvlan L2 network on the
# same parent and read the MACs:
#     docker rm -f "$A" "$B" >/dev/null
#     docker network rm "$NET" >/dev/null
#     docker network create -d ipvlan --subnet 192.168.191.0/24 -o parent="$PARENT" -o ipvlan_mode=l2 "$IPVNET" >/dev/null
#     docker run -d --name "$C" --network "$IPVNET" --ip 192.168.191.10 busybox sleep 60 >/dev/null
#     docker run -d --name "$D" --network "$IPVNET" --ip 192.168.191.11 busybox sleep 60 >/dev/null
#     parent_mac=$(cat "/sys/class/net/$PARENT/address")
#     c_mac=$(docker exec "$C" cat /sys/class/net/eth0/address)
#     d_mac=$(docker exec "$D" cat /sys/class/net/eth0/address)
#     ipv_reach=$(docker exec "$C" sh -c "ping -c1 -w2 192.168.191.11 >/dev/null 2>&1 && echo OK || echo FAIL")
parent_mac=""
c_mac=""
d_mac=""
ipv_reach=""

{
  echo "a_ip=$a_ip"
  echo "a_mac=$a_mac"
  echo "b_mac=$b_mac"
  echo "reach=$reach"
  echo "a_to_host=$a_to_host"
  echo "host_to_a=$host_to_a"
  echo "parent_mac=$parent_mac"
  echo "c_mac=$c_mac"
  echo "d_mac=$d_mac"
  echo "ipv_reach=$ipv_reach"
} > "$OUT/mac.txt"
