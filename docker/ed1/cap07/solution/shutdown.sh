#!/usr/bin/env bash
# cap07 solution - "dying gracefully": two containers, timed on docker stop. One
# runs a process as PID 1 that ignores SIGTERM (the classic 10-seconds-to-stop
# trap), the other uses --init (tini) as PID 1, which forwards the signal. The
# first waits the full grace period and is SIGKILLed (exit 137); the second stops
# at once with a clean SIGTERM (exit 143). Throwaway containers, no restart, no
# privileges: safe anywhere.
set -euo pipefail

OUT="${1:?usage: shutdown.sh OUTPUT_DIR}"
mkdir -p "$OUT"
GRACE=4
NAME="cap07-$$"
cleanup() {
  docker rm -f "${NAME}-a" "${NAME}-b" \
    "${NAME}-z-noinit" "${NAME}-z-init" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Start a container, stop it with a grace period, and print "<elapsed_ms> <exit_code>".
measure() {  # $1 = suffix ; $2.. = extra docker run flags
  local n="${NAME}-$1"; shift
  docker run -d "$@" --name "$n" busybox sleep 1000 >/dev/null
  local t0 t1
  t0=$(date +%s%N)
  docker stop -t "$GRACE" "$n" >/dev/null
  t1=$(date +%s%N)
  echo "$(( (t1 - t0) / 1000000 )) $(docker inspect -f '{{.State.ExitCode}}' "$n")"
  docker rm "$n" >/dev/null 2>&1 || true
}

# Start a zombie generator, wait for its children to exit, and print the number
# of zombie processes still visible in /proc.
count_zombies() {  # $1 = suffix ; $2.. = extra docker run flags
  local n="${NAME}-$1"; shift
  docker run -d "$@" --name "$n" busybox sh -c \
    'for i in 1 2 3 4 5; do sh -c "sleep 1 &"; done; sleep 300' >/dev/null
  sleep 4
  docker exec "$n" sh -c '
    count=0
    for stat in /proc/[0-9]*/stat; do
      read -r pid comm state rest < "$stat" || continue
      [ "$state" = Z ] && count=$((count + 1))
    done
    echo "$count"
  '
  docker rm -f "$n" >/dev/null
}

# A: sleep is PID 1 and ignores SIGTERM -> full grace, then SIGKILL (exit 137).
read -r a_ms a_code < <(measure a)
# B: --init (tini) as PID 1 forwards SIGTERM -> stops at once (exit 143 = 128+15).
read -r b_ms b_code < <(measure b --init)

# Without an init the orphaned children remain zombies; tini reaps them.
zombies_noinit=$(count_zombies z-noinit)
zombies_init=$(count_zombies z-init --init)

{
  echo "a_ms=$a_ms"
  echo "a_code=$a_code"
  echo "b_ms=$b_ms"
  echo "b_code=$b_code"
  echo "grace_ms=$(( GRACE * 1000 ))"
  echo "zombies_noinit=$zombies_noinit"
  echo "zombies_init=$zombies_init"
} > "$OUT/stop.txt"
