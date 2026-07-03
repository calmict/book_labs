#!/usr/bin/env bash
set -euo pipefail

CONTAINER=lab-cap01

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup
docker run -d --name "$CONTAINER" alpine:3 sleep infinity >/dev/null

PID=$(docker inspect --format '{{.State.Pid}}' "$CONTAINER")
echo "== PID as seen from the host =="
ps -p "$PID" -o pid,ppid,cmd
echo
echo "== /proc/<PID>/status (first lines) =="
head -5 "/proc/$PID/status"
echo
echo "== PID as seen from inside the container =="
docker exec "$CONTAINER" ps aux
echo
echo "== Hostname comparison =="
echo "host:      $(hostname)"
echo "container: $(docker exec "$CONTAINER" hostname)"
