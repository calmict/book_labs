#!/usr/bin/env bash
set -euo pipefail

# Chapter 6 solution — two network namespaces wired by hand.
# As root it builds (and tears down) the lab on the real host; as a regular
# user it re-executes itself inside a user namespace: a toy network that
# self-destructs on exit.

if [ "${1:-}" = "__inner" ]; then
  # we are the re-executed copy, fake-root inside the user namespace
  mount -t tmpfs tmpfs /run
elif [ "$(id -u)" -ne 0 ]; then
  echo "(not root: re-running inside a user namespace — a toy network,"
  echo " fully separate from the real one)"
  exec unshare -Urnm "$0" __inner
fi

cleanup() {
  ip netns del blue 2>/dev/null || true
  ip netns del red 2>/dev/null || true
  ip link del br-lab 2>/dev/null || true
}
trap cleanup EXIT
cleanup

echo "== 1-2. Two namespaces, born empty =="
ip netns add blue
ip netns add red
ip netns list
echo "--- inside blue, a newborn network ---"
ip netns exec blue ip addr

echo
echo "== 3. The switch and the two cables =="
ip link add br-lab type bridge
ip link set br-lab up
ip link add veth-blue type veth peer name veth-blue-br
ip link set veth-blue netns blue
ip link set veth-blue-br master br-lab up
ip link add veth-red type veth peer name veth-red-br
ip link set veth-red netns red
ip link set veth-red-br master br-lab up
ip link show master br-lab

echo
echo "== 4. Addresses on, lights on =="
ip netns exec blue ip addr add 10.42.0.2/24 dev veth-blue
ip netns exec blue ip link set veth-blue up
ip netns exec blue ip link set lo up
ip netns exec red ip addr add 10.42.0.3/24 dev veth-red
ip netns exec red ip link set veth-red up
ip netns exec red ip link set lo up

echo
echo "== 5. The moment of truth =="
ip netns exec blue ping -c 3 10.42.0.3
echo "--- blue's neighbour table (ARP evidence) ---"
ip netns exec blue ip neigh
echo "--- the bridge forwarding database ---"
bridge fdb show br br-lab

echo
echo "== 6. The déjà vu =="
if ip link show docker0 >/dev/null 2>&1; then
  ip addr show docker0
  echo "(same layout as br-lab: a bridge waiting for veth cables)"
else
  echo "(docker0 is not visible from the toy network — expected in the"
  echo " rootless variant; compare on the real host with: ip addr show docker0)"
fi

echo
echo "The wiring a runtime does for every container, done once by hand:"
echo "namespace + veth pair + bridge. Chapter 2 gave the rooms, this chapter"
echo "ran the cables between them."
