#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR=$(mktemp -d /tmp/labcap17.XXXXXX)
NAMESPACE_PID=
mkdir "$WORK_DIR/covered"
printf '%s\n' "visible in the underlying directory" >"$WORK_DIR/covered/labcap17-original.txt"

cleanup() {
  if [[ -n "$NAMESPACE_PID" ]] && kill -0 "$NAMESPACE_PID" 2>/dev/null; then
    kill "$NAMESPACE_PID" 2>/dev/null || true
    wait "$NAMESPACE_PID" 2>/dev/null || true
  fi
  find "$WORK_DIR" -mindepth 1 -delete 2>/dev/null || true
  rmdir "$WORK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

wait_for_stage() {
  local expected=$1
  local attempt
  # shellcheck disable=SC2034  # the retry counter is deliberately unused: the loop only bounds the wait
  for attempt in {1..100}; do
    if [[ -f "$WORK_DIR/labcap17-stage" ]] && [[ $(<"$WORK_DIR/labcap17-stage") == "$expected" ]]; then
      return 0
    fi
    sleep 0.05
  done
  echo "timed out waiting for namespace stage $expected" >&2
  return 1
}

unshare --user --map-root-user --mount --propagation private \
  "$SCRIPT_DIR/namespace-lab.sh" "$WORK_DIR" &
NAMESPACE_PID=$!

wait_for_stage mounted
echo "== Outside namespace while tmpfs is mounted inside =="
ls -la "$WORK_DIR/covered"
test -f "$WORK_DIR/covered/labcap17-original.txt"
test ! -e "$WORK_DIR/covered/labcap17-inside-only.txt"

echo "== Outside mountinfo search =="
if grep -F 'labcap17tmpfs' /proc/self/mountinfo; then
  echo "ERROR: the private mount leaked into the outside namespace" >&2
  exit 1
else
  echo "labcap17tmpfs is absent outside"
fi

echo "== Isolated view reached through /proc =="
PROC_VIEW="/proc/$NAMESPACE_PID/root$WORK_DIR/covered"
if [[ -d "$PROC_VIEW" ]] && ls -la "$PROC_VIEW"; then
  if [[ -f "$PROC_VIEW/labcap17-inside-only.txt" ]]; then
    echo "the inside-only file is reachable through /proc/$NAMESPACE_PID/root"
  else
    echo "ERROR: proc traversal did not enter the isolated mount view" >&2
    exit 1
  fi
else
  echo "SKIP: proc permissions do not allow traversal of the isolated root"
fi

: >"$WORK_DIR/labcap17-continue-mounted"
wait_for_stage unmounted
echo "== Outside namespace after private umount =="
ls -la "$WORK_DIR/covered"
test -f "$WORK_DIR/covered/labcap17-original.txt"
test ! -e "$WORK_DIR/covered/labcap17-inside-only.txt"
: >"$WORK_DIR/labcap17-continue-unmounted"

wait "$NAMESPACE_PID"
NAMESPACE_PID=
echo "private namespace exited; its mount no longer exists"
