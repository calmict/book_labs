#!/usr/bin/env bash
# cap16 - solution test. Proves how Docker networks a container: it has its own
# network namespace (inode differs from the host's), its own address on the bridge
# (two containers, two distinct IPs), and its eth0 is one end of a veth pair (local
# index differs from the peer index). Throwaway containers, default bridge only,
# no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/irete.sh" "$WORK"
host_ns=$(val "$WORK/net.txt" host_ns)
c1_ns=$(val "$WORK/net.txt" c1_ns)
c1_ip=$(val "$WORK/net.txt" c1_ip)
c2_ip=$(val "$WORK/net.txt" c2_ip)
c1_ifindex=$(val "$WORK/net.txt" c1_ifindex)
c1_iflink=$(val "$WORK/net.txt" c1_iflink)

# 1. the container has its own network namespace (different inode from the host)
if [ -z "$c1_ns" ] || [ "$c1_ns" = "$host_ns" ]; then
  echo "UNEXPECTED: the container shares the host's network namespace (c1_ns=$c1_ns host_ns=$host_ns)" >&2; exit 1
fi
echo "OK 1 - own network namespace: container $c1_ns != host $host_ns"

# 2. each container has its own address: two distinct IPs
if [ -z "$c1_ip" ] || [ -z "$c2_ip" ] || [ "$c1_ip" = "$c2_ip" ]; then
  echo "UNEXPECTED: the two containers did not get distinct IPs (c1_ip=$c1_ip c2_ip=$c2_ip)" >&2; exit 1
fi
echo "OK 2 - own address: two distinct IPs on the bridge ($c1_ip, $c2_ip)"

# 3. eth0 is one end of a veth pair: local index differs from the peer index
if [ -z "$c1_ifindex" ] || [ -z "$c1_iflink" ] || [ "$c1_ifindex" = "$c1_iflink" ]; then
  echo "UNEXPECTED: eth0 is not a veth endpoint (ifindex=$c1_ifindex iflink=$c1_iflink)" >&2; exit 1
fi
echo "OK 3 - veth pair: eth0 ifindex=$c1_ifindex, peer iflink=$c1_iflink (the other end is on the host)"

echo
echo "ALL CHECKS PASSED"
