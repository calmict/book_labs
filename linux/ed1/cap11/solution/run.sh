#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IMAGE=${LABCAP11_IMAGE:-alpine:3.20}
NAMES=(labcap11-cpu labcap11-nice labcap11-io labcap11-load)

cleanup() {
  local name
  for name in "${NAMES[@]}"; do
    docker rm -f "$name" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT INT TERM

if ! docker info >/dev/null 2>&1; then
  echo "Docker is unavailable or the current user cannot access its daemon." >&2
  exit 1
fi

cleanup

echo "== four workers sharing two CPUs =="
timeout --signal=TERM --kill-after=2s 15s docker run --rm \
  --name labcap11-cpu --cpus=2 --cpuset-cpus=0,1 --memory=128m --pids-limit=64 --network none \
  -v "$SCRIPT_DIR/container_lab.sh:/lab/container_lab.sh:ro" \
  "$IMAGE" sh /lab/container_lab.sh cpu

echo
echo "== nice under CPU contention =="
timeout --signal=TERM --kill-after=2s 30s docker run --rm \
  --name labcap11-nice --cpus=1 --cpuset-cpus=0 --memory=128m --pids-limit=64 --network none \
  -v "$SCRIPT_DIR/container_lab.sh:/lab/container_lab.sh:ro" \
  "$IMAGE" sh /lab/container_lab.sh nicecpu

echo
echo "== nice does not directly prioritize I/O =="
timeout --signal=TERM --kill-after=2s 20s docker run --rm \
  --name labcap11-io --cpus=2 --memory=192m --pids-limit=64 --network none \
  -v "$SCRIPT_DIR/container_lab.sh:/lab/container_lab.sh:ro" \
  "$IMAGE" sh /lab/container_lab.sh io

echo
echo "== high runnable load with a quarter-CPU quota =="
docker run -d --rm --name labcap11-load --cpus=0.25 --memory=128m \
  --pids-limit=64 --network none \
  -v "$SCRIPT_DIR/container_lab.sh:/lab/container_lab.sh:ro" \
  "$IMAGE" sh /lab/container_lab.sh load >/dev/null
sleep 5
docker exec labcap11-load cat /proc/loadavg \
  || echo "labcap11-load already exited before loadavg could be read" >&2
docker stats --no-stream --format \
  'container={{.Name}} cpu={{.CPUPerc}} memory={{.MemUsage}} pids={{.PIDs}}' \
  labcap11-load \
  || echo "labcap11-load already exited before stats could be read" >&2
timeout --signal=TERM --kill-after=2s 30s docker wait labcap11-load >/dev/null \
  || echo "labcap11-load was already gone by the time we waited for it" >&2

echo
echo "All scheduler checks passed; cleanup removed every labcap11 container."
