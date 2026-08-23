#!/usr/bin/env bash
# cap25 solution - "the logbook and the gauges": observability. A container writes to
# stdout and stderr; docker logs retrieves both, the logging driver (json-file) keeps
# them, and docker stats reports live metrics. Throwaway container, no restart, no
# privileges on the host.
set -euo pipefail

OUT="${1:?usage: iobs.sh OUTPUT_DIR}"
mkdir -p "$OUT"
C="cap25-$$"
UNROT="cap25-unrot-$$"; ROT="cap25-rot-$$"
cleanup() { docker rm -f "$C" "$UNROT" "$ROT" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$C" busybox sh -c 'echo hello-stdout; echo hello-stderr >&2; sleep 60' >/dev/null
sleep 1

# TODO 1 (25.1): read the container's logs (stdout+stderr merged).
logs=$(docker logs "$C" 2>&1)

# TODO 2 (25.2): read the logging driver where those logs are kept.
driver=$(docker inspect -f '{{.HostConfig.LogConfig.Type}}' "$C")

# TODO 3 (25.3): read a live resource metric (memory usage).
mem=$(docker stats --no-stream --format '{{.MemUsage}}' "$C")

# TODO 4 (25.2): identical chatty workloads, with and without json-file
# rotation. A read-only helper measures the daemon-managed files without host
# privileges or daemon changes.
chat='i=0; while [ "$i" -lt 6000 ]; do echo 012345678901234567890123456789012345678901234567890123456789; i=$((i+1)); done; sleep 60'
docker run -d --name "$UNROT" busybox sh -c "$chat" >/dev/null
docker run -d --name "$ROT" --log-opt max-size=10k --log-opt max-file=2 busybox sh -c "$chat" >/dev/null
sleep 2
log_bytes() {
  local path dir base
  path=$(docker inspect -f '{{.LogPath}}' "$1"); dir=${path%/*}; base=${path##*/}; base=${base%-json.log}
  docker run --rm -v "$dir:/logs:ro" busybox sh -c "wc -c /logs/$base-json.log* | tail -1 | awk '{print \$1}'"
}
unrotated_bytes=$(log_bytes "$UNROT")
rotated_bytes=$(log_bytes "$ROT")

# TODO 5 (25.3): link the LIMIT side of docker stats to --memory.
MEMORY_BYTES=$((64 * 1024 * 1024))
docker update --memory "$MEMORY_BYTES" --memory-swap "$MEMORY_BYTES" "$C" >/dev/null
mem_limited=$(docker stats --no-stream --format '{{.MemUsage}}' "$C")
stats_limit=$(printf '%s\n' "$mem_limited" | awk -F ' / ' '{print $2}')
configured_limit=$(docker inspect -f '{{.HostConfig.Memory}}' "$C")

{
  echo "stdout_seen=$(printf '%s' "$logs" | grep -c 'hello-stdout' || true)"
  echo "stderr_seen=$(printf '%s' "$logs" | grep -c 'hello-stderr' || true)"
  echo "driver=$driver"
  echo "mem=$mem"
  echo "unrotated_bytes=$unrotated_bytes"
  echo "rotated_bytes=$rotated_bytes"
  echo "stats_limit=$stats_limit"
  echo "configured_limit=$configured_limit"
} > "$OUT/obs.txt"
