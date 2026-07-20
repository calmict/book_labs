#!/usr/bin/env bash
# cap13 start - contrast the ephemeral container layer with a persistent volume.
# The ephemeral part is done; the volume part is missing. Three gaps (TODO 1..3).
# As written persisted and vol_exists are empty and the test fails. Throwaway
# containers (--rm), a uniquely named volume removed at the end.
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
# TODO 1 (13.3): create the named volume:
#     docker volume create "$VOL" >/dev/null

# TODO 2 (13.3): write a file INTO the volume (mounted at /data):
#     docker run --rm -v "$VOL:/data" busybox sh -c 'echo hi > /data/persisted.txt'

# TODO 3 (13.3): read it back from a fresh container mounting the same volume:
#     persisted=$(docker run --rm -v "$VOL:/data" busybox sh -c 'cat /data/persisted.txt 2>/dev/null || echo GONE')
#     vol_exists=$(docker volume ls -q | grep -cx "$VOL" || true)
persisted=""
vol_exists=""

{
  echo "ephemeral=$ephemeral"
  echo "persisted=$persisted"
  echo "vol_exists=$vol_exists"
} > "$OUT/data.txt"
