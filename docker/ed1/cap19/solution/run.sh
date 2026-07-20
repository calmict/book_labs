#!/usr/bin/env bash
# cap19 - solution test. Proves the macvlan driver: a container is addressed
# directly on the parent's subnet (not a NAT'd bridge IP); each container has its
# own MAC (an L2 identity of its own); and two containers on the same parent reach
# each other at layer 2. Requires the parent interface cap19dummy (created once
# with sudo, see README). Throwaway network and containers, no restart, real NIC
# untouched.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }
if ! ip -br link show cap19dummy >/dev/null 2>&1; then
  echo "ERROR: parent interface 'cap19dummy' not found. Create it first (see README):" >&2
  echo "  sudo ip link add cap19dummy type dummy && sudo ip link set cap19dummy up" >&2
  exit 1
fi

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/imacvlan.sh" "$WORK"
a_ip=$(val "$WORK/mac.txt" a_ip)
a_mac=$(val "$WORK/mac.txt" a_mac)
b_mac=$(val "$WORK/mac.txt" b_mac)
reach=$(val "$WORK/mac.txt" reach)

# 1. direct address: the container's IP is on the parent's subnet, not a bridge NAT
case "$a_ip" in
  192.168.190.*) ;;
  *) echo "UNEXPECTED: container IP '$a_ip' is not on the parent subnet 192.168.190.0/24" >&2; exit 1 ;;
esac
echo "OK 1 - direct address on the segment: $a_ip (parent subnet, no NAT)"

# 2. its own MAC: the two containers have distinct hardware addresses
if [ -z "$a_mac" ] || [ -z "$b_mac" ] || [ "$a_mac" = "$b_mac" ]; then
  echo "UNEXPECTED: the two containers did not get distinct MACs (a_mac=$a_mac b_mac=$b_mac)" >&2; exit 1
fi
echo "OK 2 - own MAC each: $a_mac / $b_mac (distinct L2 identities)"

# 3. same segment: the two macvlan containers reach each other at layer 2
if [ "$reach" != "OK" ]; then
  echo "UNEXPECTED: the two containers are not L2-adjacent (reach=$reach)" >&2; exit 1
fi
echo "OK 3 - same segment: the two containers reach each other by IP (L2-adjacent)"

echo
echo "ALL CHECKS PASSED"
