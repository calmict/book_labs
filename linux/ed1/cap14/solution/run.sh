#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR=$(mktemp -d /tmp/labcap14.XXXXXX)
CONTAINER=labcap14-memory-pressure
mkdir "$WORK_DIR/pressure-data"

cleanup() {
  if docker info >/dev/null 2>&1; then
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  fi
  find "$WORK_DIR" -mindepth 1 -delete 2>/dev/null || true
  rmdir "$WORK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

gcc -O2 -Wall -Wextra -Werror "$SCRIPT_DIR/fault-stats.c" -o "$WORK_DIR/fault-stats"
gcc -O2 -Wall -Wextra -Werror "$SCRIPT_DIR/cow-pages.c" -o "$WORK_DIR/cow-pages"

echo "== First and second reads of the same file =="
"$WORK_DIR/fault-stats" prepare "$WORK_DIR/pages.bin" 64
echo "-- first read --"
/usr/bin/time -v "$WORK_DIR/fault-stats" read "$WORK_DIR/pages.bin"
echo "-- second read --"
/usr/bin/time -v "$WORK_DIR/fault-stats" read "$WORK_DIR/pages.bin"

echo
echo "== Copy-on-write, one page at a time =="
"$WORK_DIR/cow-pages" 16

echo
echo "== Bounded memory pressure =="
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: the Docker daemon is not accessible; no memory pressure was applied to the host."
  exit 0
fi

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
timeout --signal=TERM --kill-after=3s 20s \
  docker run --name "$CONTAINER" \
    --memory 96m --memory-swap 96m --cpus 0.5 --pids-limit 64 \
    --read-only \
    -v "$WORK_DIR/pressure-data:/data:rw" \
    -v "$SCRIPT_DIR/memory-pressure.sh:/labcap14-memory-pressure.sh:ro" \
    alpine:3.20 sh /labcap14-memory-pressure.sh
