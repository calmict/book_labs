#!/usr/bin/env bash
# cap18 - solution test. Proves the three network drivers: host shares the host's
# network namespace (same inode, no isolation); none gives its own namespace but
# no eth0 (no connectivity); the default bridge gives its own namespace and an
# eth0 (isolated but connected). Throwaway containers, no network created, no
# restart, no privileges. It also proves host-port conflicts, ignored publishing,
# and the two valid paths to one host service. Latency is reported, not asserted.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

port_in_use() {
  local hex_port
  hex_port=$(printf '%04X' "$1")
  docker run --rm --network host busybox awk -v port=":$hex_port" \
    '$2 ~ port"$" && $4 == "0A" { found=1 } END { exit !found }' \
    /proc/net/tcp /proc/net/tcp6
}

base_port="${CAP18_PORT:-48180}"
while port_in_use "$base_port" || port_in_use "$((base_port + 1))" || port_in_use "$((base_port + 2))"; do
  old_port=$base_port
  base_port=$((base_port + 3))
  if [ "$base_port" -gt 60996 ]; then
    echo "UNEXPECTED: no free block of three high ports found for cap18" >&2
    exit 1
  fi
  echo "PRECHECK ports $old_port-$((old_port + 2)) occupied: trying $base_port-$((base_port + 2))"
done
echo "PRECHECK using host ports $base_port-$((base_port + 2)) (override the first with CAP18_PORT)"
export CAP18_PORT="$base_port"
export CAP18_FREE_PORT="$((base_port + 1))"
export CAP18_PUBLISHED_PORT="$((base_port + 2))"

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/drivers.sh" "$WORK"
host_ns=$(val "$WORK/drivers.txt" host_ns)
host_driver_ns=$(val "$WORK/drivers.txt" host_driver_ns)
none_ns=$(val "$WORK/drivers.txt" none_ns)
none_eth0=$(val "$WORK/drivers.txt" none_eth0)
bridge_ns=$(val "$WORK/drivers.txt" bridge_ns)
bridge_eth0=$(val "$WORK/drivers.txt" bridge_eth0)

# 1. host driver: the container shares the host's network namespace
if [ -z "$host_driver_ns" ] || [ "$host_driver_ns" != "$host_ns" ]; then
  echo "UNEXPECTED: host driver did not share the host netns (host_driver_ns=$host_driver_ns host_ns=$host_ns)" >&2; exit 1
fi
echo "OK 1 - host: shares the host's network namespace ($host_driver_ns) - no isolation"

# 2. none driver: own namespace, but no eth0
if [ -z "$none_ns" ] || [ "$none_ns" = "$host_ns" ] || [ "$none_eth0" != "no" ]; then
  echo "UNEXPECTED: none driver not isolated-without-eth0 (none_ns=$none_ns none_eth0=$none_eth0)" >&2; exit 1
fi
echo "OK 2 - none: own namespace ($none_ns), no eth0 - no connectivity"

# 3. default bridge: own namespace and an eth0
if [ -z "$bridge_ns" ] || [ "$bridge_ns" = "$host_ns" ] || [ "$bridge_eth0" != "yes" ]; then
  echo "UNEXPECTED: bridge not isolated-with-eth0 (bridge_ns=$bridge_ns bridge_eth0=$bridge_eth0)" >&2; exit 1
fi
echo "OK 3 - bridge: own namespace ($bridge_ns) and an eth0 - isolated but connected"

# 4. host ports collide and -p is ignored, with positive controls for both facts
conflict_status=$(val "$WORK/drivers.txt" conflict_status)
conflict_output=$(val "$WORK/drivers.txt" conflict_output)
free_running=$(val "$WORK/drivers.txt" free_running)
host_port_output=$(val "$WORK/drivers.txt" host_port_output)
bridge_port_output=$(val "$WORK/drivers.txt" bridge_port_output)
if [ "$conflict_status" -eq 0 ] || ! printf '%s' "$conflict_output" | grep -qi 'address already in use' || [ "$free_running" != "true" ]; then
  echo "UNEXPECTED: host-port conflict lacked its free-port control (status=$conflict_status free_running=$free_running output=$conflict_output)" >&2; exit 1
fi
if [ -n "$host_port_output" ] || ! printf '%s' "$bridge_port_output" | grep -q ":$CAP18_PUBLISHED_PORT"; then
  echo "UNEXPECTED: -p was not ignored only in host mode (host='$host_port_output' bridge='$bridge_port_output')" >&2; exit 1
fi
echo "OK 4 - host: same-port bind fails, free-port control works; -p is ignored, bridge mapping works"

# 5. same service: host loopback works, bridge loopback does not, gateway works
host_loopback=$(val "$WORK/drivers.txt" host_loopback)
bridge_loopback=$(val "$WORK/drivers.txt" bridge_loopback)
bridge_gateway=$(val "$WORK/drivers.txt" bridge_gateway)
requests=$(val "$WORK/drivers.txt" requests)
host_elapsed=$(val "$WORK/drivers.txt" host_elapsed)
bridge_elapsed=$(val "$WORK/drivers.txt" bridge_elapsed)
if [ "$host_loopback" != "yes" ] || [ "$bridge_loopback" != "no" ] || [ "$bridge_gateway" != "yes" ]; then
  echo "UNEXPECTED: paths to the host service differed from the network model (host_loopback=$host_loopback bridge_loopback=$bridge_loopback bridge_gateway=$bridge_gateway)" >&2; exit 1
fi
echo "INFO latency - $requests sequential requests timed inside the container (docker startup excluded): host=$host_elapsed bridge=$bridge_elapsed - usually comparable, which is the point"
echo "OK 5 - same service: host loopback works; bridge loopback fails and bridge gateway works"

echo
echo "ALL CHECKS PASSED"
