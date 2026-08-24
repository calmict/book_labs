#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR=$(mktemp -d)
PROGRAM="$WORK_DIR/memory_lab"
STATE_DIR="$WORK_DIR/state"
ACTIVE_PIDS=()

cleanup() {
  local pid
  for pid in "${ACTIVE_PIDS[@]}"; do
    kill -TERM "$pid" 2>/dev/null || true
  done
  for pid in "${ACTIVE_PIDS[@]}"; do
    wait "$pid" 2>/dev/null || true
  done
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT INT TERM

wait_for_file() {
  local path=$1
  local attempt
  # shellcheck disable=SC2034  # the retry counter is deliberately unused: the loop only bounds the wait
  for attempt in {1..100}; do
    [[ -s "$path" ]] && return 0
    sleep 0.05
  done
  echo "Timed out waiting for $path" >&2
  return 1
}

field_value() {
  local field=$1
  local path=$2
  awk -F= -v wanted="$field" '$1 == wanted { print $2; exit }' "$path"
}

memory_kb() {
  local field=$1
  local pid=$2
  awk -v wanted="$field:" '$1 == wanted { print $2; exit }' \
    "/proc/$pid/smaps_rollup"
}

cc -std=c11 -Wall -Wextra -Wpedantic -Werror -O2 \
  "$SCRIPT_DIR/memory_lab.c" -o "$PROGRAM"
mkdir "$STATE_DIR"

"$PROGRAM" alpha "$STATE_DIR" &
ALPHA_PID=$!
ACTIVE_PIDS+=("$ALPHA_PID")
"$PROGRAM" beta "$STATE_DIR" &
BETA_PID=$!
ACTIVE_PIDS+=("$BETA_PID")
wait_for_file "$STATE_DIR/alpha.initial"
wait_for_file "$STATE_DIR/beta.initial"

echo "== same virtual address, independent values =="
cat "$STATE_DIR/alpha.initial" "$STATE_DIR/beta.initial"
ALPHA_ADDRESS=$(field_value address "$STATE_DIR/alpha.initial")
BETA_ADDRESS=$(field_value address "$STATE_DIR/beta.initial")
[[ "$ALPHA_ADDRESS" == "$BETA_ADDRESS" ]]
[[ "$(field_value value "$STATE_DIR/alpha.initial")" == "alpha" ]]
[[ "$(field_value value "$STATE_DIR/beta.initial")" == "beta" ]]

kill -USR1 "$ALPHA_PID"
wait_for_file "$STATE_DIR/alpha.changed"
kill -USR2 "$ALPHA_PID" "$BETA_PID"
wait_for_file "$STATE_DIR/alpha.snapshot"
wait_for_file "$STATE_DIR/beta.snapshot"
echo "after changing alpha only:"
grep '^value=' "$STATE_DIR/alpha.snapshot" "$STATE_DIR/beta.snapshot"
[[ "$(field_value value "$STATE_DIR/alpha.snapshot")" == "alpha-changed" ]]
[[ "$(field_value value "$STATE_DIR/beta.snapshot")" == "beta" ]]

echo
echo "== selected regions from /proc/$ALPHA_PID/maps =="
MAPS_FILE="/proc/$ALPHA_PID/maps"
MAP_PREFIX=${ALPHA_ADDRESS#0x}
awk -v program="$PROGRAM" -v fixed="$MAP_PREFIX" \
  '$0 ~ program || $0 ~ /\[heap\]|\[stack\]|\[vvar\]|\[vdso\]/ || $1 ~ ("^" fixed "-") || $6 ~ /\.so/ { print }' \
  "$MAPS_FILE"
grep -qE 'r-xp .*memory_lab' "$MAPS_FILE"
grep -qE 'rw-p .*\[heap\]' "$MAPS_FILE"
grep -qE 'rw-p .*\[stack\]' "$MAPS_FILE"
grep -qE 'r-xp .*\[vdso\]' "$MAPS_FILE"
grep -qE "^${MAP_PREFIX}-.* rw-p 00000000 00:00 0" "$MAPS_FILE"

echo
echo "== RSS and PSS with shared executable and library pages =="
ALPHA_RSS=$(memory_kb Rss "$ALPHA_PID")
ALPHA_PSS=$(memory_kb Pss "$ALPHA_PID")
BETA_RSS=$(memory_kb Rss "$BETA_PID")
BETA_PSS=$(memory_kb Pss "$BETA_PID")
RSS_TOTAL=$((ALPHA_RSS + BETA_RSS))
PSS_TOTAL=$((ALPHA_PSS + BETA_PSS))
printf 'alpha: RSS=%s kB PSS=%s kB\n' "$ALPHA_RSS" "$ALPHA_PSS"
printf 'beta:  RSS=%s kB PSS=%s kB\n' "$BETA_RSS" "$BETA_PSS"
printf 'totals: RSS=%s kB PSS=%s kB\n' "$RSS_TOTAL" "$PSS_TOTAL"
[[ "$ALPHA_PSS" -lt "$ALPHA_RSS" ]]
[[ "$BETA_PSS" -lt "$BETA_RSS" ]]
[[ "$PSS_TOTAL" -lt "$RSS_TOTAL" ]]

kill -TERM "$ALPHA_PID" "$BETA_PID"
wait "$ALPHA_PID"
wait "$BETA_PID"
ACTIVE_PIDS=()

echo
echo "All virtual-memory checks passed; both test processes exited."
