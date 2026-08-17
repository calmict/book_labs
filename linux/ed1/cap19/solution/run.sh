#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR="$SCRIPT_DIR/labcap19-work"

cleanup() {
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT INT TERM

dirty_kib() {
  awk '/^Dirty:/ {print $2}' /proc/meminfo
}

elapsed_ms() {
  local started=$1
  local ended=$2
  echo $(( (ended - started) / 1000000 ))
}

show_sysfs_stack() {
  local major_minor=$1
  local sys_path
  local device_name
  local slave
  sys_path=$(readlink -f "/sys/dev/block/$major_minor") || return 0
  device_name=$(basename "$sys_path")
  if [[ -r "$sys_path/dm/name" ]]; then
    device_name="$device_name ($( < "$sys_path/dm/name" ))"
  fi
  echo "$major_minor $device_name"
  for slave in "$sys_path"/slaves/*; do
    [[ -e "$slave/dev" ]] || continue
    show_sysfs_stack "$(<"$slave/dev")"
  done
}

cleanup
mkdir -p -- "$WORK_DIR"

echo "== Dirty data around a buffered write =="
dirty_before=$(dirty_kib)
dd if=/dev/zero of="$WORK_DIR/buffered.bin" bs=1M count=64 status=none
dirty_after_write=$(dirty_kib)
sync "$WORK_DIR/buffered.bin"
dirty_after_sync=$(dirty_kib)
echo "Dirty before write:       $dirty_before KiB"
echo "Dirty after write:        $dirty_after_write KiB"
echo "Dirty after file sync:    $dirty_after_sync KiB"
echo "The counter is host-wide and writeback runs concurrently."

echo
echo "== Write duration comparison =="
started=$(date +%s%N)
dd if=/dev/zero of="$WORK_DIR/without-fsync.bin" bs=1M count=64 status=none
ended=$(date +%s%N)
without_fsync_ms=$(elapsed_ms "$started" "$ended")
started=$(date +%s%N)
dd if=/dev/zero of="$WORK_DIR/with-fsync.bin" bs=1M count=64 conv=fsync status=none
ended=$(date +%s%N)
with_fsync_ms=$(elapsed_ms "$started" "$ended")
echo "without fsync: ${without_fsync_ms} ms"
echo "with fsync:    ${with_fsync_ms} ms"

echo
echo "== Complete write, file fsync, rename, directory fsync =="
python3 "$SCRIPT_DIR/durable_replace.py" "$WORK_DIR/atomic"

echo
echo "== Synchronized copy instead of a real crash =="
printf 'labcap19 durable content\n' > "$WORK_DIR/source.txt"
dd if="$WORK_DIR/source.txt" of="$WORK_DIR/persisted.txt" bs=4K conv=fsync status=none
cmp -- "$WORK_DIR/source.txt" "$WORK_DIR/persisted.txt"
sha256sum "$WORK_DIR/source.txt" "$WORK_DIR/persisted.txt"
echo "cmp: identical"
echo "A real crash-recovery test requires a disposable virtual machine."

echo
echo "== Mount and block-device stack, read only =="
findmnt -T "$SCRIPT_DIR" -o TARGET,SOURCE,FSTYPE,OPTIONS
lsblk -o NAME,TYPE,PKNAME,FSTYPE,SIZE,MOUNTPOINTS
mount_device=$(findmnt -T "$SCRIPT_DIR" -n -o MAJ:MIN | tr -d ' ')
echo "sysfs ancestry from the mounted filesystem:"
show_sysfs_stack "$mount_device"
