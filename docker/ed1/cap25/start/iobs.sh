#!/usr/bin/env bash
# cap25 start - observability, to complete. The container is started; the three key
# reads are missing. Three gaps (TODO 1..3): logs, driver and metric are empty and
# the test fails. Throwaway container.
set -euo pipefail

OUT="${1:?usage: iobs.sh OUTPUT_DIR}"
mkdir -p "$OUT"
C="cap25-$$"
cleanup() { docker rm -f "$C" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$C" busybox sh -c 'echo hello-stdout; echo hello-stderr >&2; sleep 60' >/dev/null
sleep 1

# TODO 1 (25.1): read the container's logs (stdout+stderr merged):
#     logs=$(docker logs "$C" 2>&1)
logs=""

# TODO 2 (25.2): read the logging driver where those logs are kept:
#     driver=$(docker inspect -f '{{.HostConfig.LogConfig.Type}}' "$C")
driver=""

# TODO 3 (25.3): read a live resource metric (memory usage):
#     mem=$(docker stats --no-stream --format '{{.MemUsage}}' "$C")
mem=""

{
  echo "stdout_seen=$(printf '%s' "$logs" | grep -c 'hello-stdout' || true)"
  echo "stderr_seen=$(printf '%s' "$logs" | grep -c 'hello-stderr' || true)"
  echo "driver=$driver"
  echo "mem=$mem"
} > "$OUT/obs.txt"
