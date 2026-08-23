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

# TODO 4 (16.1+16.2): create the container namespace, veth pair and br-cap16;
# assign 10.16.0.1/24 to the bridge and 10.16.0.2/24 to eth0 in the namespace.

# TODO 5 (16.3): create the external namespace on 192.0.2.0/24, enable IPv4
# forwarding and add one narrowly scoped POSTROUTING MASQUERADE rule.

# TODO 6: send one ping from the container namespace to 192.0.2.2, then record
# the bridge membership and the MASQUERADE packet counter in cablaggio.txt.

echo "TODO 4..6: complete the hand-built network" >&2
exit 1
