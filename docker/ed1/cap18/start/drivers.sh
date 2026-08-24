#!/usr/bin/env bash
# cap18 start - the network drivers side by side, to complete. Five gaps
# (TODO 1..5): the driver reads, the port comparison and the two paths to the
# same host service are missing. The three throwaway servers below are already
# started for you: what is missing is what you read from them.
set -euo pipefail

OUT="${1:?usage: drivers.sh OUTPUT_DIR}"
mkdir -p "$OUT"
printf '%s\n' 'cap18 host service' > "$OUT/index.html"

PORT="${CAP18_PORT:?CAP18_PORT is required}"
FREE_PORT="${CAP18_FREE_PORT:?CAP18_FREE_PORT is required}"
PUBLISHED_PORT="${CAP18_PUBLISHED_PORT:?CAP18_PUBLISHED_PORT is required}"
REQUESTS="${CAP18_REQUESTS:-100}"
SUFFIX="$$"
HOST_SERVER="cap18-host-server-$SUFFIX"
FREE_SERVER="cap18-free-server-$SUFFIX"
BRIDGE_SERVER="cap18-bridge-server-$SUFFIX"

cleanup() {
  docker rm -f "$HOST_SERVER" "$FREE_SERVER" "$BRIDGE_SERVER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

host_ns=$(readlink /proc/self/ns/net)

# TODO 1 (18.1): host driver - the container shares the host's network namespace:
#     host_driver_ns=$(docker run --rm --network host busybox readlink /proc/self/ns/net)
host_driver_ns=""

# TODO 2 (18.2): none driver - own namespace, but no eth0 (no connectivity):
#     none_ns=$(docker run --rm --network none busybox readlink /proc/self/ns/net)
#     none_eth0=$(docker run --rm --network none busybox sh -c '[ -e /sys/class/net/eth0 ] && echo yes || echo no')
none_ns=""
none_eth0=""

# TODO 3 (18.4): default bridge - own namespace and an eth0 (isolated but connected):
#     bridge_ns=$(docker run --rm busybox readlink /proc/self/ns/net)
#     bridge_eth0=$(docker run --rm busybox sh -c '[ -e /sys/class/net/eth0 ] && echo yes || echo no')
bridge_ns=""
bridge_eth0=""

# Given: one server in host mode on PORT (with a -p that host mode will ignore),
# one in host mode on a free port, one on the default bridge publishing a port.
docker run -d --rm --name "$HOST_SERVER" --network host \
  -p "$PUBLISHED_PORT:$PORT" -v "$OUT:/www:ro" \
  busybox httpd -f -p "$PORT" -h /www >/dev/null
docker run -d --rm --name "$FREE_SERVER" --network host \
  -v "$OUT:/www:ro" busybox httpd -f -p "$FREE_PORT" -h /www >/dev/null
docker run -d --rm --name "$BRIDGE_SERVER" \
  -p "$PUBLISHED_PORT:80" -v "$OUT:/www:ro" \
  busybox httpd -f -p 80 -h /www >/dev/null
sleep 1

# TODO 4 (18.1): host mode takes the host's own port, and -p is ignored there.
# Try the same port again in host mode (it must fail), then read the control on
# the free port, then compare what "docker port" says in the two modes:
#     set +e
#     conflict_output=$(docker run --rm --network host -v "$OUT:/www:ro" busybox httpd -f -p "$PORT" -h /www 2>&1)
#     conflict_status=$?
#     set -e
#     free_running=$(docker inspect -f '{{.State.Running}}' "$FREE_SERVER")
#     host_port_output=$(docker port "$HOST_SERVER")
#     bridge_port_output=$(docker port "$BRIDGE_SERVER" 80/tcp)
conflict_status=""
conflict_output=""
free_running=""
host_port_output=""
bridge_port_output=""

# TODO 5 (18.3): the same service, seen from two vantage points. In host mode
# 127.0.0.1 IS the host's loopback; on the bridge it is the container's own, so
# there the way in is the gateway of the default route:
#     host_loopback=$(docker run --rm --network host busybox wget -q -O /dev/null "http://127.0.0.1:$PORT" && echo yes || echo no)
#     bridge_loopback=$(docker run --rm busybox wget -q -T 1 -O /dev/null "http://127.0.0.1:$PORT" 2>/dev/null && echo yes || echo no)
#     bridge_gateway=$(docker run --rm busybox sh -c 'gateway=$(ip route | awk '\''/default/ { print $3; exit }'\''); wget -q -O /dev/null "http://$gateway:'"$PORT"'" && echo yes || echo no')
host_loopback=""
bridge_loopback=""
bridge_gateway=""

# And the timing of the two paths, measured INSIDE the container so that the
# startup of docker run stays out of the figure. It is information, not a test:
#     host_elapsed=$(docker run --rm --network host busybox sh -c \
#       'time sh -c "i=0; while [ \$i -lt '"$REQUESTS"' ]; do wget -q -O /dev/null http://127.0.0.1:'"$PORT"'; i=\$((i+1)); done"' 2>&1 |
#       awk '/^real/ { print $2, $3 }')
#     bridge_elapsed=$(docker run --rm busybox sh -c \
#       'gateway=$(ip route | awk '\''/default/ { print $3; exit }'\''); time sh -c "i=0; while [ \$i -lt '"$REQUESTS"' ]; do wget -q -O /dev/null http://$gateway:'"$PORT"'; i=\$((i+1)); done"' 2>&1 |
#       awk '/^real/ { print $2, $3 }')
host_elapsed=""
bridge_elapsed=""

{
  echo "host_ns=$host_ns"
  echo "host_driver_ns=$host_driver_ns"
  echo "none_ns=$none_ns"
  echo "none_eth0=$none_eth0"
  echo "bridge_ns=$bridge_ns"
  echo "bridge_eth0=$bridge_eth0"
  echo "conflict_status=$conflict_status"
  echo "conflict_output=$conflict_output"
  echo "free_running=$free_running"
  echo "host_port_output=$host_port_output"
  echo "bridge_port_output=$bridge_port_output"
  echo "host_loopback=$host_loopback"
  echo "bridge_loopback=$bridge_loopback"
  echo "bridge_gateway=$bridge_gateway"
  echo "requests=$REQUESTS"
  echo "host_elapsed=$host_elapsed"
  echo "bridge_elapsed=$bridge_elapsed"
} > "$OUT/drivers.txt"
