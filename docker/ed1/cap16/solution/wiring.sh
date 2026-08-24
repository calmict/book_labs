#!/usr/bin/env bash
# cap16 solution - build, inside an unprivileged user+network namespace, the
# same kernel plumbing Docker uses: network namespace, veth, bridge and NAT.
set -euo pipefail

OUT="${1:?usage: wiring.sh OUTPUT_DIR [__inner]}"
MODE="${2:-}"
mkdir -p "$OUT"

if [ "$MODE" != "__inner" ]; then
  exec unshare -Urnm "$0" "$OUT" __inner
fi

# ip netns keeps its bind mounts below /run/netns, a directory that does not
# exist yet on a machine where ip netns was never used. A throwaway tmpfs over
# /run gives this mount namespace its own instance: the directory is surely
# there, and no entry can escape into the host's one.
mount -t tmpfs none /run
mkdir -p /run/netns

NS_CONTAINER="cap16-container-$$"
NS_EXTERNAL="cap16-external-$$"
BRIDGE="br-cap16"
VETH_BRIDGE="veth-cap16-br"
VETH_CONTAINER="veth-cap16-ns"
VETH_EXTERNAL="veth-cap16-out"
VETH_WORLD="veth-c16-world"

cleanup() {
  ip netns del "$NS_CONTAINER" >/dev/null 2>&1 || true
  ip netns del "$NS_EXTERNAL" >/dev/null 2>&1 || true
  ip link del "$VETH_BRIDGE" >/dev/null 2>&1 || true
  ip link del "$VETH_EXTERNAL" >/dev/null 2>&1 || true
  ip link del "$BRIDGE" >/dev/null 2>&1 || true
  umount /run >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Private side: one container namespace, one veth pair and one miniature docker0.
ip netns add "$NS_CONTAINER"
ip link add "$BRIDGE" type bridge
ip addr add 10.16.0.1/24 dev "$BRIDGE"
ip link set "$BRIDGE" up
ip link add "$VETH_BRIDGE" type veth peer name "$VETH_CONTAINER"
ip link set "$VETH_BRIDGE" master "$BRIDGE"
ip link set "$VETH_BRIDGE" up
ip link set "$VETH_CONTAINER" netns "$NS_CONTAINER"
ip -n "$NS_CONTAINER" link set lo up
ip -n "$NS_CONTAINER" link set "$VETH_CONTAINER" name eth0
ip -n "$NS_CONTAINER" addr add 10.16.0.2/24 dev eth0
ip -n "$NS_CONTAINER" link set eth0 up
ip -n "$NS_CONTAINER" route add default via 10.16.0.1

# External side: a second namespace stands in for the Internet.
ip netns add "$NS_EXTERNAL"
ip link add "$VETH_EXTERNAL" type veth peer name "$VETH_WORLD"
ip addr add 192.0.2.1/24 dev "$VETH_EXTERNAL"
ip link set "$VETH_EXTERNAL" up
ip link set "$VETH_WORLD" netns "$NS_EXTERNAL"
ip -n "$NS_EXTERNAL" link set lo up
ip -n "$NS_EXTERNAL" addr add 192.0.2.2/24 dev "$VETH_WORLD"
ip -n "$NS_EXTERNAL" link set "$VETH_WORLD" up

# Route packets between the two simulated networks and translate the private
# source on exit. The rule exists only in this throwaway network namespace.
sysctl -q -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s 10.16.0.0/24 -o "$VETH_EXTERNAL" -j MASQUERADE

bridge_member=$(ip -o link show master "$BRIDGE" | grep -c "$VETH_BRIDGE")
container_ip=$(ip -n "$NS_CONTAINER" -o -4 addr show dev eth0 | awk '{print $4}')
bridge_addr=$(ip -o -4 addr show dev "$BRIDGE" | awk '{print $4}')

# A real packet crosses the boundary. Its hit on the narrowly scoped rule proves
# that MASQUERADE processed it; the external peer can reply only to 192.0.2.1.
ip netns exec "$NS_CONTAINER" ping -c 1 -W 2 192.0.2.2 >/dev/null
nat_packets=$(iptables -t nat -L POSTROUTING -n -v -x | awk '$3 == "MASQUERADE" && $8 == "10.16.0.0/24" {print $1; exit}')

{
  echo "bridge=$BRIDGE"
  echo "bridge_member=$bridge_member"
  echo "container_ip=$container_ip"
  echo "bridge_addr=$bridge_addr"
  echo "external_gateway=192.0.2.1"
  echo "external_peer=192.0.2.2"
  echo "nat_out=$VETH_EXTERNAL"
  echo "nat_packets=${nat_packets:-0}"
} > "$OUT/cablaggio.txt"
