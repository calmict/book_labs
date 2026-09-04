#!/usr/bin/env bash
set -euo pipefail

OUT=${1:?usage: observe.sh OUTPUT_DIR}
CONTAINER=lab-cap01
mkdir -p "$OUT"
cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
docker run -d --name "$CONTAINER" alpine:3 sleep infinity >/dev/null
HOST_PID=$(docker inspect --format '{{.State.Pid}}' "$CONTAINER")
{
  echo "host_pid=$HOST_PID"
  echo "host_hostname=$(hostname)"
  echo "process_count=$(ps -e --no-headers | wc -l)"
} > "$OUT/host.txt"
docker exec "$CONTAINER" sh -c '
  {
    echo "inside_pid=$(ps -o pid,comm | awk '\''$2 == "sleep" {print $1}'\'')"
    echo "inside_hostname=$(hostname)"
    echo "process_count=$(ps -e | tail -n +2 | wc -l)"
  } > /tmp/inside.txt
'
docker cp "$CONTAINER:/tmp/inside.txt" "$OUT/inside.txt"
