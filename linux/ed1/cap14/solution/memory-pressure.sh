#!/bin/sh
set -eu

WORK_DIR=/data

show_metrics() {
  echo "memory.current=$(cat /sys/fs/cgroup/memory.current 2>/dev/null || echo unavailable)"
  if [ -r /sys/fs/cgroup/memory.stat ]; then
    awk '$1 == "pgscan" || $1 == "pgsteal" || $1 == "pgscan_direct" || $1 == "pgsteal_direct" || $1 == "workingset_refault_file" { print }' /sys/fs/cgroup/memory.stat
  fi
  if [ -r /sys/fs/cgroup/memory.pressure ]; then
    sed -n '1,2p' /sys/fs/cgroup/memory.pressure
  fi
}

mkdir -p "$WORK_DIR"
echo "== cgroup metrics before pressure =="
show_metrics

index=0
while [ "$index" -lt 32 ]; do
  dd if=/dev/zero of="$WORK_DIR/page-set-$index" bs=1M count=4 status=none
  index=$((index + 1))
done

deadline=$(( $(date +%s) + 8 ))
passes=0
while [ "$(date +%s)" -lt "$deadline" ]; do
  cat "$WORK_DIR"/page-set-* >/dev/null
  passes=$((passes + 1))
done

echo "passes over a 128 MiB file set: $passes"
echo "== cgroup metrics after pressure =="
show_metrics
