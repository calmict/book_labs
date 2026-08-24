#!/usr/bin/env bash
# cap19 - solution test. Proves the macvlan driver: a container is addressed
# directly on the parent's subnet (not a NAT'd bridge IP); each container has its
# own MAC (an L2 identity of its own); and two containers on the same parent reach
# each other at layer 2. It then shows the hairpin limit - the host holds an
# address on the same subnet and still does not reach the container, in either
# direction - and compares the driver with ipvlan, whose children share the
# parent's MAC. Requires the parent interface cap19dummy with its address (created
# once with sudo, see README). Throwaway networks and containers, no restart, real
# NIC untouched.
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
# the host must be ON the segment, otherwise the hairpin check would only measure
# a missing route instead of the isolation between a macvlan child and its parent
if ! ip -4 -br addr show cap19dummy | grep -q '192[.]168[.]190[.]1/24'; then
  echo "ERROR: 'cap19dummy' has no address on the segment. Add it (see README):" >&2
  echo "  sudo ip addr add 192.168.190.1/24 dev cap19dummy" >&2
  exit 1
fi

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/imacvlan.sh" "$WORK"
a_ip=$(val "$WORK/mac.txt" a_ip)
a_mac=$(val "$WORK/mac.txt" a_mac)
b_mac=$(val "$WORK/mac.txt" b_mac)
reach=$(val "$WORK/mac.txt" reach)
a_to_host=$(val "$WORK/mac.txt" a_to_host)
host_to_a=$(val "$WORK/mac.txt" host_to_a)
parent_mac=$(val "$WORK/mac.txt" parent_mac)
c_mac=$(val "$WORK/mac.txt" c_mac)
d_mac=$(val "$WORK/mac.txt" d_mac)
ipv_reach=$(val "$WORK/mac.txt" ipv_reach)

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

# 4. the hairpin limit: a macvlan child and its own parent are isolated by design
if [ "$a_to_host" != "FAIL" ] || [ "$host_to_a" != "FAIL" ]; then
  echo "UNEXPECTED: child and parent reached each other (a_to_host=$a_to_host host_to_a=$host_to_a)" >&2; exit 1
fi
echo "OK 4 - hairpin limit: the sibling answers, the host on the same subnet does not, in either direction"

# 5. the other driver: ipvlan children share the parent's MAC, macvlan ones do not
if [ -z "$parent_mac" ] || [ "$c_mac" != "$parent_mac" ] || [ "$d_mac" != "$parent_mac" ]; then
  echo "UNEXPECTED: the ipvlan containers do not carry the parent MAC (parent=$parent_mac c=$c_mac d=$d_mac)" >&2; exit 1
fi
if [ "$a_mac" = "$parent_mac" ]; then
  echo "UNEXPECTED: the macvlan container carries the parent MAC too (a_mac=$a_mac)" >&2; exit 1
fi
if [ "$ipv_reach" != "OK" ]; then
  echo "UNEXPECTED: the two ipvlan containers do not reach each other (ipv_reach=$ipv_reach)" >&2; exit 1
fi
echo "OK 5 - the other driver: the two ipvlan containers share the parent MAC $parent_mac and still reach each other, where macvlan gave each its own"

echo
echo "ALL CHECKS PASSED"
