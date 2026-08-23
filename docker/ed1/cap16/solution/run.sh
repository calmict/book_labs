#!/usr/bin/env bash
# cap16 - solution test. Proves how Docker networks a container: it has its own
# network namespace (inode differs from the host's), its own address on the bridge
# (two containers, two distinct IPs), and its eth0 is one end of a veth pair (local
# index differs from the peer index). Throwaway containers, default bridge only,
# no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
COMPARE="cap16compare-$$"
cleanup() {
  docker rm -f "$COMPARE" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }
for tool in unshare ip bridge iptables ping sysctl mount umount; do
  command -v "$tool" >/dev/null || { echo "ERROR: $tool not found (see SETUP.md)" >&2; exit 1; }
done

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

# Read-only observation of Docker's real bridge. Never inspect host iptables:
# an unprivileged reader cannot do so, and the lab does not need elevated rights.
docker run -d --name "$COMPARE" busybox sleep 60 >/dev/null
ip addr show docker0 > "$WORK/docker0.txt"
bridge link > "$WORK/docker-bridge-links.txt"

"$HERE/ilcablaggio.sh" "$WORK"
bridge_name=$(val "$WORK/cablaggio.txt" bridge)
bridge_member=$(val "$WORK/cablaggio.txt" bridge_member)
container_ip=$(val "$WORK/cablaggio.txt" container_ip)
bridge_addr=$(val "$WORK/cablaggio.txt" bridge_addr)
nat_packets=$(val "$WORK/cablaggio.txt" nat_packets)

# 4. the hand-built namespace has an eth0 connected by veth to our bridge
if [ "$bridge_name" != "br-cap16" ] || [ "$bridge_member" -ne 1 ] || [ "$container_ip" != "10.16.0.2/24" ]; then
  echo "UNEXPECTED: incomplete hand-built bridge/veth topology (bridge=$bridge_name member=$bridge_member container_ip=$container_ip)" >&2; exit 1
fi
echo "OK 4 - hand-built cable: container eth0 is connected by veth to $bridge_name (gateway $bridge_addr)"

# 5. traffic reached the simulated outside through the real MASQUERADE rule
if [ "${nat_packets:-0}" -lt 1 ]; then
  echo "UNEXPECTED: MASQUERADE did not translate any packet (packets=${nat_packets:-0})" >&2; exit 1
fi
echo "OK 5 - simulated Internet: MASQUERADE translated $nat_packets packet(s) at the private/external boundary"

# 6. compare structure, without touching the real Docker bridge or host NAT
grep -q 'docker0' "$WORK/docker0.txt" || { echo "UNEXPECTED: docker0 was not visible in the read-only host inspection" >&2; exit 1; }
grep -q 'master docker0' "$WORK/docker-bridge-links.txt" || { echo "UNEXPECTED: the comparison container's veth was not attached to docker0" >&2; exit 1; }
echo "OK 6 - Docker comparison: docker0 and $bridge_name both provide a bridge, veth endpoints and a private subnet"

echo
echo "ALL CHECKS PASSED"
