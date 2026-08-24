#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR=$(mktemp -d /tmp/labcap16.XXXXXX)
HELPER_PID=

cleanup() {
  if [[ -n "$HELPER_PID" ]] && kill -0 "$HELPER_PID" 2>/dev/null; then
    kill "$HELPER_PID" 2>/dev/null || true
    wait "$HELPER_PID" 2>/dev/null || true
  fi
  find "$WORK_DIR" -mindepth 1 -delete 2>/dev/null || true
  rmdir "$WORK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

wait_for_text() {
  local file=$1
  local expected=$2
  local attempt
  for attempt in {1..100}; do
    if [[ -f "$file" ]] && [[ $(<"$file") == "$expected" ]]; then
      return 0
    fi
    sleep 0.05
  done
  echo "timed out waiting for $expected" >&2
  return 1
}

wait_for_file() {
  local file=$1
  local attempt
  # shellcheck disable=SC2034  # the retry counter is deliberately unused: the loop only bounds the wait
  for attempt in {1..100}; do
    [[ -f "$file" ]] && return 0
    sleep 0.05
  done
  echo "timed out waiting for $file" >&2
  return 1
}

command -v lsof >/dev/null 2>&1 || {
  echo "lsof is required" >&2
  exit 1
}

echo "== Descriptors across open and close =="
python3 "$SCRIPT_DIR/fd-lifecycle.py" "$WORK_DIR" &
HELPER_PID=$!

for stage in before-open after-open after-close; do
  wait_for_text "$WORK_DIR/labcap16-stage" "$stage"
  echo "-- $stage, pid $HELPER_PID --"
  ls -l "/proc/$HELPER_PID/fd"
  : >"$WORK_DIR/labcap16-continue-$stage"
done
wait "$HELPER_PID"
HELPER_PID=

echo
echo "== Redirection replaces descriptor number 1 =="
(
  exec 3>&1
  redirect_pid=$BASHPID
  echo "descriptor 1 before: $(readlink "/proc/$redirect_pid/fd/1")" >&3
  exec 1>"$WORK_DIR/labcap16-redirected-output.txt"
  echo "descriptor 1 after:  $(readlink "/proc/$redirect_pid/fd/1")" >&3
  echo "this line travels through descriptor 1"
)
echo "file contents: $(<"$WORK_DIR/labcap16-redirected-output.txt")"

echo
echo "== An unlinked file remains through its descriptor =="
dd if=/dev/zero of="$WORK_DIR/labcap16-held-open.bin" bs=1M count=16 status=none
python3 "$SCRIPT_DIR/hold-open.py" "$WORK_DIR" &
HELPER_PID=$!
wait_for_file "$WORK_DIR/labcap16-held-ready"
echo "helper: $(<"$WORK_DIR/labcap16-held-ready")"
HELPER_FD=$(sed -E 's/.* fd=([0-9]+).*/\1/' "$WORK_DIR/labcap16-held-ready")
unlink "$WORK_DIR/labcap16-held-open.bin"
echo "-- lsof after unlink, before close --"
lsof +L1 -a -p "$HELPER_PID" 2>/dev/null
echo "descriptor target: $(readlink "/proc/$HELPER_PID/fd/$HELPER_FD")"
: >"$WORK_DIR/labcap16-close-held"
wait_for_file "$WORK_DIR/labcap16-held-closed"
echo "-- lsof after close --"
if lsof +L1 -a -p "$HELPER_PID" 2>/dev/null | grep -F 'labcap16-held-open.bin'; then
  echo "ERROR: the deleted lab file is still open" >&2
  exit 1
else
  echo "no deleted lab file remains open"
fi
wait "$HELPER_PID"
HELPER_PID=
