#!/usr/bin/env bash
# cap14 start - the three mount types side by side, to complete. Three gaps
# (TODO 1..3): the bind write, the volume read-back and the tmpfs mount are
# missing, so the measurements are empty/GONE and the test fails. Throwaway
# containers, a uniquely named volume and a temp folder.
set -euo pipefail

OUT="${1:?usage: imontaggi.sh OUTPUT_DIR}"
mkdir -p "$OUT"
VOL="cap14-$$"
HOSTDIR="$OUT/hostdir"
mkdir -p "$HOSTDIR"
cleanup() { docker volume rm -f "$VOL" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# 1) BIND MOUNT: a host folder mounted in; the container's write lands on the host.
# TODO 1 (14.2): mount HOSTDIR at /mnt and write a file there:
#     docker run --rm -v "$HOSTDIR:/mnt" busybox sh -c 'echo frombind > /mnt/b.txt'
bind_host=$(cat "$HOSTDIR/b.txt" 2>/dev/null || echo GONE)

# 2) VOLUME: daemon-managed, persists across containers.
docker volume create "$VOL" >/dev/null
docker run --rm -v "$VOL:/data" busybox sh -c 'echo fromvol > /data/v.txt'
# TODO 2 (14.1): read it back from a fresh container mounting the same volume:
#     vol_persist=$(docker run --rm -v "$VOL:/data" busybox sh -c 'cat /data/v.txt 2>/dev/null || echo GONE')
vol_persist=""

# 3) TMPFS: in-memory, never on disk/host, not persisted.
# TODO 3 (14.3): mount a tmpfs at /cache, write to it, report the mount type:
#     tmpfs_type=$(docker run --rm --tmpfs /cache busybox sh -c 'echo x > /cache/t.txt; grep -q " /cache tmpfs " /proc/mounts && echo TMPFS || echo other')
tmpfs_type=""

{
  echo "bind_host=$bind_host"
  echo "vol_persist=$vol_persist"
  echo "tmpfs_type=$tmpfs_type"
} > "$OUT/mounts.txt"
