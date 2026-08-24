#!/usr/bin/env bash
# cap16 start - build Docker's network plumbing by hand, to complete.
set -euo pipefail

OUT="${1:?usage: ilcablaggio.sh OUTPUT_DIR [__inner]}"
MODE="${2:-}"
mkdir -p "$OUT"

if [ "$MODE" != "__inner" ]; then
  exec unshare -Urnm "$0" "$OUT" __inner
fi

# ip netns keeps its bind mounts below /run/netns: a throwaway tmpfs over /run
# gives this mount namespace its own instance, without touching the host's one.
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

# Here the exercise changes register. In irete.sh you read what Docker had already
# built, and the line to write was given. From here on you build, and the line is
# yours: the operations and the commands in play are named, the arguments are not.
# Laying the bricks in order is the whole point of the chapter.

# TODO 4 (16.1+16.2): the private side. The variables above already hold every
#   name you need. In order: create the container namespace (ip netns add); create
#   the bridge and give it 10.16.0.1/24; create the veth pair (ip link add ... type
#   veth peer name ...); leave one end on the bridge (ip link set ... master ...)
#   and push the other into the namespace (ip link set ... netns ...). Inside the
#   namespace (ip -n "$NS_CONTAINER" ...) rename that end to eth0, address it
#   10.16.0.2/24, bring up lo and eth0, and add the default route via the bridge.
#   Both ends of every cable must be up, or the ping of TODO 6 never leaves.

# TODO 5 (16.3): a controlled outside, and the translation towards it. A second
#   namespace holds 192.0.2.2/24 at the far end of another veth pair, whose near
#   end keeps 192.0.2.1/24 here. Two things then make the crossing possible:
#   routing (sysctl -w net.ipv4.ip_forward=1) and translation, one POSTROUTING rule
#   in the nat table (iptables -t nat -A ... -j MASQUERADE) scoped to source
#   10.16.0.0/24 and to the external interface. Both live in this throwaway network
#   namespace and nowhere else.

# TODO 6: prove it, then report. One ping (ip netns exec ... ping -c 1) from the
#   container namespace to 192.0.2.2 must succeed. Read the rule's packet counter
#   AFTER it (iptables -t nat -L POSTROUTING -n -v -x): read before, the number
#   would only say the rule was written, not crossed. Then write "$OUT/cablaggio.txt"
#   with one key=value per line, exactly these names - solution/run.sh reads them:
#     bridge=<bridge name>              bridge_member=<1 if the veth is on it>
#     container_ip=<eth0 address>       bridge_addr=<bridge address>
#     external_gateway=192.0.2.1        external_peer=192.0.2.2
#     nat_out=<external interface>      nat_packets=<counter after the ping>

echo "TODO 4..6: complete the hand-built network" >&2
exit 1
