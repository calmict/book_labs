#!/usr/bin/env bash
# Complete TODO 1..3 to observe one container process from the host and from
# inside its namespaces.
set -euo pipefail

CONTAINER=lab-cap01
cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

docker run -d --name "$CONTAINER" alpine:3 sleep infinity >/dev/null

# TODO 1 (1.2): obtain the host PID assigned to the container's init process.
# Use docker inspect so the following host-side /proc lookup targets that process.
HOST_PID=

# TODO 2 (1.2): record the host view in host.txt.
# Write host_pid, host_hostname and process_count key/value lines.

# TODO 3 (1.3): record the container view in inside.txt.
# Use docker exec to write the equivalent three keys from inside the container.
