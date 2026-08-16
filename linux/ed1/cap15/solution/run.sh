#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR=$(mktemp -d /tmp/labcap15.XXXXXX)
IMAGE=${LABCAP15_IMAGE:-python:3.12-alpine}
CACHE_CONTAINER=labcap15-page-cache
OVERCOMMIT_CONTAINER=labcap15-overcommit
OOM_CONTAINER=labcap15-oom
mkdir "$WORK_DIR/cache-data"

cleanup() {
  if docker info >/dev/null 2>&1; then
    docker rm -f "$CACHE_CONTAINER" "$OVERCOMMIT_CONTAINER" "$OOM_CONTAINER" >/dev/null 2>&1 || true
  fi
  find "$WORK_DIR" -mindepth 1 -delete 2>/dev/null || true
  rmdir "$WORK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: the Docker daemon is not accessible. No memory workload was run on the host."
  exit 0
fi

docker rm -f "$CACHE_CONTAINER" "$OVERCOMMIT_CONTAINER" "$OOM_CONTAINER" >/dev/null 2>&1 || true

echo "== Page cache: free and available memory =="
timeout --signal=TERM --kill-after=3s 25s \
  docker run --name "$CACHE_CONTAINER" \
    --memory 192m --memory-swap 192m --cpus 0.5 --pids-limit 64 --network none \
    --read-only --tmpfs /tmp:rw,nosuid,nodev,size=8m \
    -v "$WORK_DIR/cache-data:/data:rw" \
    -v "$SCRIPT_DIR/cache-memory.py:/labcap15-cache-memory.py:ro" \
    "$IMAGE" python3 /labcap15-cache-memory.py
docker inspect --format 'limits: memory={{.HostConfig.Memory}} memory-swap={{.HostConfig.MemorySwap}}' "$CACHE_CONTAINER"

echo
echo "== Overcommit: reserve without touching =="
timeout --signal=TERM --kill-after=3s 15s \
  docker run --name "$OVERCOMMIT_CONTAINER" \
    --memory 192m --memory-swap 192m --cpus 0.5 --pids-limit 64 --network none --read-only \
    -v "$SCRIPT_DIR/untouched-allocation.py:/labcap15-untouched-allocation.py:ro" \
    "$IMAGE" python3 /labcap15-untouched-allocation.py
docker inspect --format 'limits: memory={{.HostConfig.Memory}} memory-swap={{.HostConfig.MemorySwap}}' "$OVERCOMMIT_CONTAINER"

echo
echo "== Contained OOM =="
set +e
timeout --signal=TERM --kill-after=3s 30s \
  docker run --name "$OOM_CONTAINER" \
    --memory 128m --memory-swap 128m --cpus 0.5 --pids-limit 64 --network none --read-only \
    -v "$SCRIPT_DIR/oom-allocator.py:/labcap15-oom-allocator.py:ro" \
    "$IMAGE" python3 /labcap15-oom-allocator.py
run_status=$?
set -e

echo "-- final allocator log --"
docker logs "$OOM_CONTAINER"
inspect_result=$(docker inspect --format 'oom={{.State.OOMKilled}} exit={{.State.ExitCode}} memory={{.HostConfig.Memory}} memory-swap={{.HostConfig.MemorySwap}}' "$OOM_CONTAINER")
echo "$inspect_result"

if [ "$run_status" -ne 137 ] || [[ "$inspect_result" != oom=true\ exit=137* ]]; then
  echo "ERROR: expected a contained OOM with exit code 137, got command status $run_status" >&2
  exit 1
fi
