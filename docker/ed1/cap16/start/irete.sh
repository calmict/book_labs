#!/usr/bin/env bash
# cap16 start - read a container's network stack, to complete. Two containers run
# at once on the default bridge; the three key reads are missing. Three gaps
# (TODO 1..3): namespace, addresses and veth indices are empty and the test
# fails. A fourth gap (TODO 7) reads the NAT rules Docker writes for its bridge.
# Throwaway containers and images, default bridge only.
set -euo pipefail

OUT="${1:?usage: irete.sh OUTPUT_DIR}"
mkdir -p "$OUT"
C1="cap16a-$$"
C2="cap16b-$$"
NAT_TAG="cap16nat-$$"
cleanup() {
  docker rm -f "$C1" "$C2" >/dev/null 2>&1 || true
  docker rmi -f "$NAT_TAG" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# two containers running at the same time, so each keeps its own address
docker run -d --name "$C1" busybox sleep 60 >/dev/null
docker run -d --name "$C2" busybox sleep 60 >/dev/null

host_ns=$(readlink /proc/self/ns/net)

# TODO 1 (16.1): read the first container's own network namespace:
#     c1_ns=$(docker exec "$C1" readlink /proc/self/ns/net)
c1_ns=""

# TODO 2 (16.4): read the eth0 IP of each container (their own, distinct addresses):
#     c1_ip=$(docker exec "$C1" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')
#     c2_ip=$(docker exec "$C2" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')
c1_ip=""
c2_ip=""

# TODO 3 (16.2): read the veth peer index (iflink) vs the local index (ifindex):
#     c1_ifindex=$(docker exec "$C1" cat /sys/class/net/eth0/ifindex)
#     c1_iflink=$(docker exec "$C1" cat /sys/class/net/eth0/iflink)
c1_ifindex=""
c1_iflink=""

# TODO 7 (16.3): read the MASQUERADE rule Docker writes for its own bridge. It
# needs privileges you do not have on the host, so borrow the host's network
# namespace inside a throwaway container with NET_ADMIN and read only:
#     printf 'FROM alpine:3\nRUN apk add --no-cache iptables\n' | docker build -q -t "$NAT_TAG" - >/dev/null
#     docker_subnet=$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Subnet}}')
#     docker_masq_out=$(docker run --rm --network host --cap-add NET_ADMIN "$NAT_TAG" \
#       iptables -t nat -L POSTROUTING -n -v -x |
#       awk -v subnet="$docker_subnet" '$3 == "MASQUERADE" && $8 == subnet {print $7; exit}')
docker_subnet=""
docker_masq_out=""

{
  echo "host_ns=$host_ns"
  echo "c1_ns=$c1_ns"
  echo "c1_ip=$c1_ip"
  echo "c2_ip=$c2_ip"
  echo "c1_ifindex=$c1_ifindex"
  echo "c1_iflink=$c1_iflink"
  echo "docker_subnet=$docker_subnet"
  echo "docker_masq_out=$docker_masq_out"
} > "$OUT/net.txt"
