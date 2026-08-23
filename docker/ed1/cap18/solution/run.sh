#!/usr/bin/env bash
# cap18 - solution test. Proves the three network drivers: host shares the host's
# network namespace (same inode, no isolation); none gives its own namespace but
# no eth0 (no connectivity); the default bridge gives its own namespace and an
# eth0 (isolated but connected). Throwaway containers, no network created, no
# restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/idriver.sh" "$WORK"
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

echo
echo "ALL CHECKS PASSED"
