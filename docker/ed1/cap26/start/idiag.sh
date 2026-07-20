#!/usr/bin/env bash
# cap26 start - troubleshooting a mute, crash-looping container, to complete. The
# container is started; the three key reads are missing. Three gaps (TODO 1..3):
# logs, exit code and restart counter are empty and the test fails. Throwaway
# container.
set -euo pipefail

OUT="${1:?usage: idiag.sh OUTPUT_DIR}"
mkdir -p "$OUT"
C="cap26-$$"
cleanup() { docker rm -f "$C" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# exits silently with code 42, under a restart policy -> crash loop, then gives up
docker run -d --name "$C" --restart on-failure:3 busybox sh -c 'exit 42' >/dev/null
sleep 6   # let the crash loop finish

# TODO 1 (26.1): read the container's logs (it is mute - empty):
#     logs=$(docker logs "$C" 2>&1)
logs=""

# TODO 2 (26.2): read the exit code from inspect (the real diagnosis):
#     exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$C")
exit_code=""

# TODO 3 (26.3): read how many times it restarted and its final status:
#     restart_count=$(docker inspect -f '{{.RestartCount}}' "$C")
#     status=$(docker inspect -f '{{.State.Status}}' "$C")
restart_count=""
status=""

{
  echo "logs_len=$(printf '%s' "$logs" | wc -c)"
  echo "exit_code=$exit_code"
  echo "restart_count=$restart_count"
  echo "status=$status"
} > "$OUT/diag.txt"
