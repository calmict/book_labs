#!/usr/bin/env bash
# cap18 - solution test. Proves the three network drivers: host shares the host's
# network namespace (same inode, no isolation); none gives its own namespace but
# no eth0 (no connectivity); the default bridge gives its own namespace and an
# eth0 (isolated but connected). Then it reproduces the chapter's two traps: the
# port published in host mode that is discarded, the collision between two
# containers that want the same port, and the name that does not resolve on the
# default bridge. Throwaway containers, no network created, no restart, no
# privileges.
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
hostmode_ports=$(val "$WORK/drivers.txt" hostmode_ports)
first_state=$(val "$WORK/drivers.txt" first_state)
second_state=$(val "$WORK/drivers.txt" second_state)
second_log=$(val "$WORK/drivers.txt" second_log)
dns=$(val "$WORK/drivers.txt" dns)

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

# 4. host mode: -p is discarded, because there is no NAT to publish anything through
if [ -n "${hostmode_ports// /}" ]; then
  echo "UNEXPECTED: host mode published something (docker port -> $hostmode_ports)" >&2; exit 1
fi
echo "OK 4 - host: -p is ignored, nothing is published (docker port prints nothing)"

# 5. the trap that follows: two containers, one port, no NAT to keep them apart
if [ "$first_state" != "true" ]; then
  echo "UNEXPECTED: the first listener is not running - is port 18080 already in use on the host?" >&2; exit 1
fi
if [ "$second_state" != "false" ]; then
  echo "UNEXPECTED: the second listener is still running (second_state=$second_state)," >&2
  echo "            expected it to fail on the port already taken" >&2; exit 1
fi
case "$second_log" in
  *"in use"*) : ;;
  *) echo "UNEXPECTED: the second listener died saying '$second_log', expected an address-in-use error" >&2; exit 1 ;;
esac
echo "OK 5 - host: two containers cannot share a port - the second says \"$second_log\""

# 6. the second trap: on the default bridge names are not resolved
if [ "$dns" != "FAILED" ]; then
  echo "UNEXPECTED: the name resolved on the default bridge (dns=$dns)" >&2; exit 1
fi
echo "OK 6 - default bridge: another container's name does not resolve ($dns) - no embedded DNS here"

echo
echo "ALL CHECKS PASSED"
