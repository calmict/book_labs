#!/usr/bin/env bash
# cap13 solution - "what stays ashore": contrast two fates. A file written into a
# container's own writable layer is not visible to a fresh container (ephemeral);
# a file written into a named volume is read back by a fresh container after the
# first is removed (persistent), and the volume outlives every container.
# Throwaway containers (--rm), a uniquely named volume removed at the end: safe.
set -euo pipefail

OUT="${1:?usage: aterra.sh OUTPUT_DIR}"
mkdir -p "$OUT"
VOL="cap13-$$"
cleanup() { docker volume rm -f "$VOL" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# A) EPHEMERAL: write into the container's own writable layer, remove it, then a
#    fresh container from the same image does NOT see the file.
docker run --rm busybox sh -c 'echo hi > /ephemeral.txt'
ephemeral=$(docker run --rm busybox sh -c 'cat /ephemeral.txt 2>/dev/null || echo GONE')

# B) PERSISTENT: a named volume, outside any container's layer.
# TODO 1 (13.3): create the named volume.
docker volume create "$VOL" >/dev/null
# TODO 2 (13.3): write a file INTO the volume (mounted at /data); the container is
#   then removed, but the file lives in the volume, not in the container layer.
docker run --rm -v "$VOL:/data" busybox sh -c 'echo hi > /data/persisted.txt'
# TODO 3 (13.3): a fresh container mounting the same volume reads it back.
persisted=$(docker run --rm -v "$VOL:/data" busybox sh -c 'cat /data/persisted.txt 2>/dev/null || echo GONE')

# the volume is a first-class object: it still exists with no container using it.
vol_exists=$(docker volume ls -q | grep -cx "$VOL" || true)

{
  echo "ephemeral=$ephemeral"
  echo "persisted=$persisted"
  echo "vol_exists=$vol_exists"
} > "$OUT/data.txt"
