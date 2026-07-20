#!/usr/bin/env bash
# cap07 start - two containers, timed on docker stop, to reveal the PID 1 signal
# trap. Throwaway containers, no restart, no privileges. Three gaps to fill
# (TODO 1..3). As written the stop is not timed and no exit code is recorded.
set -euo pipefail

OUT="${1:?usage: congrazia.sh OUTPUT_DIR}"
mkdir -p "$OUT"
GRACE=4
NAME="cap07-$$"
cleanup() { docker rm -f "${NAME}-a" "${NAME}-b" >/dev/null 2>&1 || true; }
trap cleanup EXIT

measure() {  # $1 = suffix ; $2.. = extra docker run flags
  local n="${NAME}-$1"; shift
  docker run -d "$@" --name "$n" busybox sleep 1000 >/dev/null

  # TODO 1 (7.3): stop the container with the grace period and time it. docker
  #   stop sends SIGTERM, waits GRACE seconds, then SIGKILLs. Fill in:
  #     local t0 t1
  #     t0=$(date +%s%N)
  #     docker stop -t "$GRACE" "$n" >/dev/null
  #     t1=$(date +%s%N)

  # TODO 3 (7.3): print "<elapsed_ms> <exit_code>". Read the exit code with
  #   docker inspect -f '{{.State.ExitCode}}' - it is 137 (SIGKILL) if PID 1
  #   ignored SIGTERM, 143 (SIGTERM) if it stopped cleanly:
  #     echo "$(( (t1 - t0) / 1000000 )) $(docker inspect -f '{{.State.ExitCode}}' "$n")"

  docker rm "$n" >/dev/null
}

# A: sleep is PID 1 and ignores SIGTERM -> full grace, then SIGKILL (exit 137).
read -r a_ms a_code < <(measure a)

# TODO 2 (7.5): container B must use --init (tini as PID 1) so SIGTERM is
#   forwarded to sleep and the container stops at once. Add the --init flag:
#     read -r b_ms b_code < <(measure b --init)
read -r b_ms b_code < <(measure b)

{
  echo "a_ms=$a_ms"
  echo "a_code=$a_code"
  echo "b_ms=$b_ms"
  echo "b_code=$b_code"
  echo "grace_ms=$(( GRACE * 1000 ))"
} > "$OUT/stop.txt"
