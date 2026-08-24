#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR=$(mktemp -d /tmp/labcap09.XXXXXX)
PROGRAM=$WORK_DIR/labcap09-process
INSPECT_PID=
ZOMBIE_PARENT=
FIFO_PID=
DELAY_PID=
DM_NAME=labcap09-delay
DM_CREATED=0
LOOP_DEV=
UDEV_RULE_FILE=/run/udev/rules.d/12-labcap09-delay.rules
UDEV_RULE_WRITTEN=0

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
  stop_process "$DELAY_PID"
  if (( DM_CREATED )); then
    remove_delay_device || true
  fi
  if (( UDEV_RULE_WRITTEN )); then
    rm -f -- "$UDEV_RULE_FILE"
    udevadm control --reload-rules >/dev/null 2>&1 || true
  fi
  if [[ -n "$LOOP_DEV" ]]; then
    losetup -d "$LOOP_DEV" >/dev/null 2>&1 || true
  fi
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

remove_delay_device() {
  # The udev rule installed below stops udev from ever opening the device, so
  # removal should succeed on the first try; a short retry stays as a safety
  # net for timing edge cases on machines other than the one this was built on.
  local attempts_left=15
  while (( attempts_left > 0 )); do
    if timeout 5 dmsetup remove --noudevsync "$DM_NAME" 2>/dev/null; then
      return 0
    fi
    attempts_left=$((attempts_left - 1))
    sleep 0.2
  done
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
# shellcheck disable=SC2034  # the retry counter is deliberately unused: the loop only bounds the wait
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
echo "== dm-delay wait: a genuine uninterruptible state (optional, needs root) =="
if (( EUID != 0 )); then
  echo "SKIP: this step needs root to create a device-mapper node. Rerun as: sudo solution/run.sh"
else
  for command_name in dmsetup losetup truncate basename udevadm; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      echo "Required command is missing: $command_name" >&2
      exit 2
    fi
  done
  if dmsetup ls 2>/dev/null | awk '{ print $1 }' | grep -Fxq "$DM_NAME"; then
    echo "ERROR device-mapper name $DM_NAME already exists; remove it before rerunning" >&2
    exit 1
  fi

  # udev's own disk rules run blkid against every new device-mapper node and
  # set an inotify watch on it; against a delay target each blkid read can
  # itself cost the full delay, and dmsetup remove refuses an open device, so
  # the two interact badly. A volatile rule scoped to this device name only
  # (removed below, /run never persists across reboot) tells udev to leave it
  # alone entirely instead of racing it. The "12" prefix matters: rules run in
  # filename order, and this must load after 10-dm.rules (which sets DM_NAME,
  # matched below) but before 13-dm-disk.rules (which runs blkid) — a later
  # prefix like 90 would lose the race and never stop it.
  mkdir -p -- "$(dirname "$UDEV_RULE_FILE")"
  printf '%s\n' \
    'ACTION!="remove", SUBSYSTEM=="block", KERNEL=="dm-[0-9]*", ENV{DM_NAME}=="'"$DM_NAME"'", ENV{DM_UDEV_DISABLE_DISK_RULES_FLAG}="1", ENV{DM_UDEV_DISABLE_OTHER_RULES_FLAG}="1", OPTIONS:="nowatch"' \
    > "$UDEV_RULE_FILE"
  UDEV_RULE_WRITTEN=1
  udevadm control --reload-rules

  BACKING_FILE=$WORK_DIR/labcap09-delay-backing.img
  truncate -s 32M "$BACKING_FILE"
  LOOP_DEV=$(losetup -f --show "$BACKING_FILE")
  # --noudevsync: dmsetup normally waits for udev to ack the new node before
  # returning; on some hosts that ack never arrives even though the kernel
  # already created the mapping. Skipping the wait is harmless everywhere,
  # including hosts where udev works fine or where the rule above already
  # keeps udev from touching this device at all.
  timeout 20 dmsetup create "$DM_NAME" --noudevsync \
    --table "0 65536 delay $LOOP_DEV 0 5000"
  DM_CREATED=1
  major_minor=$(dmsetup ls | awk -v n="$DM_NAME" '$1 == n { gsub(/[()]/, "", $2); print $2 }')
  dm_node=$(basename "$(readlink -f "/sys/dev/block/$major_minor")")
  DM_DEV=/dev/$dm_node
  [[ -b "$DM_DEV" ]]

  # iflag=direct: a buffered read can be served from the block device's page
  # cache and return instantly without ever reaching the delay target — the
  # udev rule above stops that from happening via blkid's own probing, but
  # O_DIRECT forces a real read through dm-delay regardless of what else
  # might have touched the device.
  dd if="$DM_DEV" of=/dev/null bs=4096 count=1 iflag=direct &
  DELAY_PID=$!
  delay_state=
  for _ in {1..150}; do
    delay_state=$(ps -o stat= -p "$DELAY_PID" 2>/dev/null | awk '{ print $1 }')
    [[ "$delay_state" == D* ]] && break
    sleep 0.02
  done
  ps -o pid,ppid,stat,wchan:24,comm -p "$DELAY_PID"
  sed -n '/^State:/p' "/proc/$DELAY_PID/status"
  dmsetup status "$DM_NAME"
  [[ "$delay_state" == D* ]]
  wait "$DELAY_PID"
  delay_exit=$?
  DELAY_PID=
  printf 'dd exit code: %s\n' "$delay_exit"
  [[ "$delay_exit" == 0 ]]

  if ! remove_delay_device; then
    echo "ERROR $DM_NAME still busy after retries; something other than udev's disk rules must have it open" >&2
    exit 1
  fi
  DM_CREATED=0
  rm -f -- "$UDEV_RULE_FILE"
  udevadm control --reload-rules
  UDEV_RULE_WRITTEN=0
  losetup -d "$LOOP_DEV"
  LOOP_DEV=
  rm -f "$BACKING_FILE"
  echo "Measured conclusion: dm-delay produces a genuine uninterruptible D state, unlike the FIFO wait above."
fi

echo
echo "All reproducible process checks passed."
