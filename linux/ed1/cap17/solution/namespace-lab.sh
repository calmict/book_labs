#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]] || [[ $1 != /tmp/labcap17.* ]]; then
  echo "usage: $0 /tmp/labcap17.SUFFIX" >&2
  exit 2
fi

WORK_DIR=$1
COVERED_DIR=$WORK_DIR/covered
STAGE_FILE=$WORK_DIR/labcap17-stage
MOUNTED=false

cleanup() {
  if [[ $MOUNTED == true ]]; then
    umount "$COVERED_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

wait_for_ack() {
  local name=$1
  local attempt
  for attempt in {1..100}; do
    [[ -f "$WORK_DIR/labcap17-continue-$name" ]] && return 0
    sleep 0.05
  done
  echo "timed out waiting for acknowledgement $name" >&2
  return 1
}

echo "== Inside namespace: before mount =="
ls -la "$COVERED_DIR"

mount -t tmpfs -o size=4m,nosuid,nodev labcap17tmpfs "$COVERED_DIR"
MOUNTED=true
printf '%s\n' "visible only through the private mount" >"$COVERED_DIR/labcap17-inside-only.txt"

echo "== Inside namespace: tmpfs mounted =="
ls -la "$COVERED_DIR"
grep -F 'labcap17tmpfs' /proc/self/mountinfo
printf '%s\n' mounted >"$STAGE_FILE"
wait_for_ack mounted

umount "$COVERED_DIR"
MOUNTED=false
echo "== Inside namespace: after umount =="
ls -la "$COVERED_DIR"
printf '%s\n' unmounted >"$STAGE_FILE"
wait_for_ack unmounted
