#!/usr/bin/env bash
# cap26 solution - "the black box of the mute container": troubleshooting. A
# container exits silently with a non-zero code under a restart policy, crash-looping
# until the policy gives up. With no logs to read, the diagnosis comes from docker
# inspect: the exit code and the restart counter. Throwaway container, no restart of
# the daemon, no privileges.
set -euo pipefail

OUT="${1:?usage: idiag.sh OUTPUT_DIR}"
mkdir -p "$OUT"
C="cap26-$$"
cleanup() { docker rm -f "$C" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# exits silently with code 42, under a restart policy -> crash loop, then gives up
docker run -d --name "$C" --restart on-failure:3 busybox sh -c 'exit 42' >/dev/null
sleep 6   # let the crash loop finish

# TODO 1 (26.1): read the container's logs (it is mute - empty).
logs=$(docker logs "$C" 2>&1)

# TODO 2 (26.2): read the exit code from inspect (the real diagnosis).
exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$C")

# TODO 3 (26.3): read how many times it restarted and its final status.
restart_count=$(docker inspect -f '{{.RestartCount}}' "$C")
status=$(docker inspect -f '{{.State.Status}}' "$C")

{
  echo "logs_len=$(printf '%s' "$logs" | wc -c)"
  echo "exit_code=$exit_code"
  echo "restart_count=$restart_count"
  echo "status=$status"
} > "$OUT/diag.txt"
