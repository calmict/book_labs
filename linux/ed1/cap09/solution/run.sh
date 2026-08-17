#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR=$(mktemp -d /tmp/labcap09.XXXXXX)
PROGRAM=$WORK_DIR/labcap09-process
INSPECT_PID=
ZOMBIE_PARENT=
FIFO_PID=

stop_process() {
  process_id=$1
  if [[ -n "$process_id" ]] && kill -0 "$process_id" 2>/dev/null; then
    kill -TERM "$process_id" 2>/dev/null || true
    for attempt in {1..30}; do
      kill -0 "$process_id" 2>/dev/null || break
      sleep 0.02
    done
    if kill -0 "$process_id" 2>/dev/null; then
      kill -KILL "$process_id" 2>/dev/null || true
    fi
  fi
  if [[ -n "$process_id" ]]; then
    wait "$process_id" 2>/dev/null || true
  fi
}

cleanup() {
  status=$?
  trap - EXIT INT TERM
  stop_process "$FIFO_PID"
  stop_process "$ZOMBIE_PARENT"
  stop_process "$INSPECT_PID"
  rm -rf -- "$WORK_DIR"
  if [[ ! -e "$WORK_DIR" ]]; then
    echo "Cleanup check: PASS (lab processes stopped and $WORK_DIR removed)"
  else
    echo "Cleanup check: FAIL" >&2
    status=1
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

wait_for_file() {
  path=$1
  for attempt in {1..100}; do
    [[ -s "$path" ]] && return 0
    sleep 0.02
  done
  echo "Timed out waiting for $path" >&2
  return 1
}

for command_name in cc ps awk sed readlink mkfifo; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is missing: $command_name" >&2
    exit 2
  fi
done

cc -std=c11 -Wall -Wextra -Wpedantic -Werror -O2 \
  "$SCRIPT_DIR/process-lab.c" -o "$PROGRAM"

echo "== live process through /proc =="
"$PROGRAM" inspect "$WORK_DIR" &
INSPECT_PID=$!
wait_for_file "$WORK_DIR/inspect-ready"
recorded_inspect_pid=$(sed -n '1p' "$WORK_DIR/inspect-ready")
[[ "$recorded_inspect_pid" == "$INSPECT_PID" ]]
ps -o pid,ppid,stat,comm -p "$INSPECT_PID"
sed -n -E '/^(Name|State|Pid|PPid|VmRSS|Threads):/p' "/proc/$INSPECT_PID/status"

echo "Open descriptors:"
open_file_found=0
for descriptor_path in "/proc/$INSPECT_PID/fd/"*; do
  descriptor_target=$(readlink "$descriptor_path" 2>/dev/null || true)
  printf '%s -> %s\n' "${descriptor_path##*/}" "$descriptor_target"
  if [[ "$descriptor_target" == "$WORK_DIR/labcap09-open-file.txt" ]]; then
    open_file_found=1
  fi
done
[[ "$open_file_found" == 1 ]]

echo "Memory rollup:"
sed -n -E '/^(Rss|Pss|Private_Clean|Private_Dirty):/p' "/proc/$INSPECT_PID/smaps_rollup"
rss_kib=$(awk '/^Rss:/ { print $2 }' "/proc/$INSPECT_PID/smaps_rollup")
[[ "$rss_kib" -gt 0 ]]

echo "Namespace links:"
namespace_count=0
for namespace_path in "/proc/$INSPECT_PID/ns/"*; do
  printf '%s -> %s\n' "${namespace_path##*/}" "$(readlink "$namespace_path")"
  namespace_count=$((namespace_count + 1))
done
[[ "$namespace_count" -gt 0 ]]
kill -TERM "$INSPECT_PID"
wait "$INSPECT_PID"
INSPECT_PID=
echo "Live-process inspection: PASS"

echo
echo "== zombie before and after waitpid =="
"$PROGRAM" zombie "$WORK_DIR" &
ZOMBIE_PARENT=$!
wait_for_file "$WORK_DIR/zombie-parent.pid"
wait_for_file "$WORK_DIR/zombie-child.pid"
recorded_parent=$(sed -n '1p' "$WORK_DIR/zombie-parent.pid")
zombie_child=$(sed -n '1p' "$WORK_DIR/zombie-child.pid")
[[ "$recorded_parent" == "$ZOMBIE_PARENT" ]]
zombie_state=
for attempt in {1..100}; do
  zombie_state=$(ps -o stat= -p "$zombie_child" 2>/dev/null | awk '{ print $1 }')
  [[ "$zombie_state" == Z* ]] && break
  sleep 0.02
done
ps -o pid,ppid,stat,wchan:24,comm -p "$zombie_child"
sed -n -E '/^(Name|State|Pid|PPid):/p' "/proc/$zombie_child/status"
[[ "$zombie_state" == Z* ]]
kill -USR1 "$ZOMBIE_PARENT"
wait_for_file "$WORK_DIR/zombie-reaped"
wait "$ZOMBIE_PARENT"
ZOMBIE_PARENT=
if [[ -e "/proc/$zombie_child" ]]; then
  echo "Zombie PID $zombie_child still exists after waitpid" >&2
  exit 1
fi
echo "Zombie PID $zombie_child absent after waitpid: PASS"

echo
echo "== FIFO wait: measured state and SIGKILL =="
FIFO_PATH=$WORK_DIR/labcap09-never-written.fifo
FIFO_PID_PATH=$WORK_DIR/fifo.pid
mkfifo "$FIFO_PATH"
"$PROGRAM" fifo "$FIFO_PATH" "$FIFO_PID_PATH" &
FIFO_PID=$!
wait_for_file "$FIFO_PID_PATH"
recorded_fifo_pid=$(sed -n '1p' "$FIFO_PID_PATH")
[[ "$recorded_fifo_pid" == "$FIFO_PID" ]]
fifo_state=
for attempt in {1..100}; do
  fifo_state=$(ps -o stat= -p "$FIFO_PID" 2>/dev/null | awk '{ print $1 }')
  [[ "$fifo_state" == S* ]] && break
  sleep 0.02
done
ps -o pid,ppid,stat,wchan:24,comm -p "$FIFO_PID"
sed -n '/^State:/p' "/proc/$FIFO_PID/status"
[[ "$fifo_state" == S* ]]
[[ "$fifo_state" != D* ]]
kill -KILL "$FIFO_PID"
set +e
wait "$FIFO_PID"
fifo_wait_status=$?
set -e
FIFO_PID=
printf 'wait status after SIGKILL: %s\n' "$fifo_wait_status"
[[ "$fifo_wait_status" == 137 ]]
if [[ -e "/proc/$recorded_fifo_pid" ]]; then
  echo "FIFO PID $recorded_fifo_pid still exists after SIGKILL" >&2
  exit 1
fi
echo "FIFO PID $recorded_fifo_pid absent after SIGKILL: PASS"
echo "Measured conclusion: a FIFO wait is interruptible state S, not state D."

echo
echo "All reproducible process checks passed."
