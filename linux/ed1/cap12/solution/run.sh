#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR=$(mktemp -d)
PROGRAM="$WORK_DIR/signal_service"
IMAGE=${LABCAP12_IMAGE:-alpine:3.20}
ACTIVE_PID=
CONTAINERS=(labcap12-slow labcap12-fixed)

cleanup() {
  local name
  if [[ -n "$ACTIVE_PID" ]]; then
    kill -KILL "$ACTIVE_PID" 2>/dev/null || true
    wait "$ACTIVE_PID" 2>/dev/null || true
  fi
  for name in "${CONTAINERS[@]}"; do
    docker rm -f "$name" >/dev/null 2>&1 || true
  done
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT INT TERM

wait_for_file() {
  local path=$1
  local attempt
  for attempt in {1..100}; do
    [[ -e "$path" ]] && return 0
    sleep 0.05
  done
  echo "Timed out waiting for $path" >&2
  return 1
}

wait_for_text() {
  local text=$1
  local path=$2
  local attempt
  # shellcheck disable=SC2034  # the retry counter is deliberately unused: the loop only bounds the wait
  for attempt in {1..100}; do
    grep -Fq "$text" "$path" 2>/dev/null && return 0
    sleep 0.05
  done
  echo "Timed out waiting for '$text' in $path" >&2
  return 1
}

cc -std=c11 -Wall -Wextra -Wpedantic -Werror -O2 \
  "$SCRIPT_DIR/signal_service.c" -o "$PROGRAM"

echo "== SIGHUP reload and orderly SIGTERM shutdown =="
GRACE_DIR="$WORK_DIR/graceful"
mkdir "$GRACE_DIR"
printf 'mode=initial\n' >"$GRACE_DIR/service.conf"
"$PROGRAM" "$GRACE_DIR/service.conf" "$GRACE_DIR/service.log" \
  "$GRACE_DIR/work.marker" "$GRACE_DIR/ready.marker" &
ACTIVE_PID=$!
wait_for_file "$GRACE_DIR/ready.marker"
ORIGINAL_PID=$ACTIVE_PID
printf 'mode=reloaded\n' >"$GRACE_DIR/service.conf"
kill -HUP "$ACTIVE_PID"
wait_for_text "loaded mode=reloaded" "$GRACE_DIR/service.log"
kill -0 "$ORIGINAL_PID"
kill -TERM "$ACTIVE_PID"
wait "$ACTIVE_PID"
ACTIVE_PID=
grep -Fq "orderly shutdown" "$GRACE_DIR/service.log"
[[ ! -e "$GRACE_DIR/work.marker" ]]
cat "$GRACE_DIR/service.log"
printf 'PID remained %s across reload; work marker removed after SIGTERM\n' "$ORIGINAL_PID"

echo
echo "== SIGKILL prevents application cleanup =="
KILL_DIR="$WORK_DIR/killed"
mkdir "$KILL_DIR"
printf 'mode=kill-test\n' >"$KILL_DIR/service.conf"
"$PROGRAM" "$KILL_DIR/service.conf" "$KILL_DIR/service.log" \
  "$KILL_DIR/work.marker" "$KILL_DIR/ready.marker" &
ACTIVE_PID=$!
wait_for_file "$KILL_DIR/ready.marker"
KILLED_PID=$ACTIVE_PID
kill -KILL "$ACTIVE_PID"
set +e
wait "$ACTIVE_PID" 2>/dev/null
KILL_STATUS=$?
set -e
ACTIVE_PID=
[[ "$KILL_STATUS" -eq 137 ]]
[[ -e "$KILL_DIR/work.marker" ]]
printf 'PID %s exited with status %s; work marker still exists\n' \
  "$KILLED_PID" "$KILL_STATUS"

echo
echo "== container stop timeout and PID 1 fix =="
if ! docker info >/dev/null 2>&1; then
  echo "Docker is unavailable or the current user cannot access its daemon." >&2
  exit 1
fi
docker ps --format '{{.Names}}' >/dev/null
for name in "${CONTAINERS[@]}"; do
  docker rm -f "$name" >/dev/null 2>&1 || true
done

timeout --signal=TERM --kill-after=2s 5s docker run -d --rm \
  --name labcap12-slow --cpus=0.25 --memory=64m --pids-limit=32 --network none \
  "$IMAGE" sh -c 'trap "" TERM; sleep 60 & wait' >/dev/null
SLOW_START=$SECONDS
timeout --signal=TERM --kill-after=2s 15s \
  docker stop --time 10 labcap12-slow >/dev/null
SLOW_SECONDS=$((SECONDS - SLOW_START))
printf 'container ignoring SIGTERM: %s seconds\n' "$SLOW_SECONDS"
[[ "$SLOW_SECONDS" -ge 9 ]]

timeout --signal=TERM --kill-after=2s 5s docker run -d --rm \
  --name labcap12-fixed --cpus=0.25 --memory=64m --pids-limit=32 --network none \
  -v "$SCRIPT_DIR/container_entrypoint.sh:/lab/container_entrypoint.sh:ro" \
  "$IMAGE" sh /lab/container_entrypoint.sh >/dev/null
FIXED_START=$SECONDS
timeout --signal=TERM --kill-after=2s 15s \
  docker stop --time 10 labcap12-fixed >/dev/null
FIXED_SECONDS=$((SECONDS - FIXED_START))
printf 'container handling SIGTERM: %s seconds\n' "$FIXED_SECONDS"
[[ "$FIXED_SECONDS" -lt 5 ]]

echo
echo "All signal checks passed; cleanup removed every labcap12 container."
