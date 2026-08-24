#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR=$(mktemp -d)
PROGRAM="$WORK_DIR/process_lab"
ACTIVE_PID=

cleanup() {
  if [[ -n "$ACTIVE_PID" ]]; then
    kill "$ACTIVE_PID" 2>/dev/null || true
    wait "$ACTIVE_PID" 2>/dev/null || true
  fi
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT INT TERM

wait_for_file() {
  local path=$1
  local attempt
  for attempt in {1..50}; do
    [[ -s "$path" ]] && return 0
    sleep 0.05
  done
  echo "Timed out waiting for $path" >&2
  return 1
}

cc -std=c11 -Wall -Wextra -Wpedantic -Werror -O2 \
  "$SCRIPT_DIR/process_lab.c" -o "$PROGRAM"

echo "== fork observed from another process =="
FORK_STATE="$WORK_DIR/fork-state"
"$PROGRAM" fork "$FORK_STATE" &
ACTIVE_PID=$!
wait_for_file "$FORK_STATE/parent.pid"
wait_for_file "$FORK_STATE/child.pid"
PARENT_PID=$(<"$FORK_STATE/parent.pid")
CHILD_PID=$(<"$FORK_STATE/child.pid")
ps -o pid,ppid,stat,comm -p "$PARENT_PID,$CHILD_PID"
OBSERVED_PPID=$(ps -o ppid= -p "$CHILD_PID" | tr -d ' ')
[[ "$OBSERVED_PPID" == "$PARENT_PID" ]]
wait "$ACTIVE_PID"
ACTIVE_PID=

echo
echo "== PID preserved across exec =="
EXEC_STATE="$WORK_DIR/exec-state"
"$PROGRAM" exec "$EXEC_STATE" &
ACTIVE_PID=$!
wait_for_file "$EXEC_STATE/exec-before.pid"
BEFORE_PID=$(<"$EXEC_STATE/exec-before.pid")
for attempt in {1..50}; do
  AFTER_NAME=$(ps -o comm= -p "$ACTIVE_PID" | tr -d ' ')
  [[ "$AFTER_NAME" == "sleep" ]] && break
  sleep 0.05
done
AFTER_PID=$ACTIVE_PID
printf 'before exec: PID=%s, program=process_lab\n' "$BEFORE_PID"
printf 'after exec:  PID=%s, program=%s\n' "$AFTER_PID" "$AFTER_NAME"
[[ "$BEFORE_PID" == "$AFTER_PID" && "$AFTER_NAME" == "sleep" ]]
wait "$ACTIVE_PID"
ACTIVE_PID=

echo
echo "== zombie reaped by its parent =="
ZOMBIE_STATE="$WORK_DIR/zombie-state"
"$PROGRAM" zombie "$ZOMBIE_STATE" &
ACTIVE_PID=$!
wait_for_file "$ZOMBIE_STATE/zombie-parent.pid"
wait_for_file "$ZOMBIE_STATE/zombie-child.pid"
ZOMBIE_PARENT=$(<"$ZOMBIE_STATE/zombie-parent.pid")
ZOMBIE_CHILD=$(<"$ZOMBIE_STATE/zombie-child.pid")
# shellcheck disable=SC2034  # the retry counter is deliberately unused: the loop only bounds the wait
for attempt in {1..50}; do
  ZOMBIE_STAT=$(ps -o stat= -p "$ZOMBIE_CHILD" | tr -d ' ')
  [[ "$ZOMBIE_STAT" == Z* ]] && break
  sleep 0.05
done
ps -o pid,ppid,stat,comm -p "$ZOMBIE_CHILD"
[[ "$ZOMBIE_STAT" == Z* ]]
kill -USR1 "$ZOMBIE_PARENT"
wait_for_file "$ZOMBIE_STATE/reaped"
if ps -p "$ZOMBIE_CHILD" >/dev/null; then
  echo "Zombie PID $ZOMBIE_CHILD still exists" >&2
  exit 1
fi
echo "after SIGUSR1 to parent $ZOMBIE_PARENT: child PID $ZOMBIE_CHILD is absent"
wait "$ACTIVE_PID"
ACTIVE_PID=

echo
echo "All process lifecycle checks passed."
