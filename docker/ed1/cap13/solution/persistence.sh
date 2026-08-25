#!/usr/bin/env bash
# cap13 solution - "what stays ashore": contrast two fates. A file written into a
# container's own writable layer is not visible to a fresh container (ephemeral);
# a file written into a named volume is read back by a fresh container after the
# first is removed (persistent), and the volume outlives every container. It also
# distinguishes stop/start from remove/recreate and reads structured disk usage.
# All resources have unique names and are removed at the end.
set -euo pipefail

OUT="${1:?usage: persistence.sh OUTPUT_DIR}"
mkdir -p "$OUT"
VOL="cap13-$$"
LIFE_CONTAINER="cap13-life-$$"
cleanup() {
  docker rm -f "$LIFE_CONTAINER" >/dev/null 2>&1 || true
  docker volume rm -f "$VOL" >/dev/null 2>&1 || true
}
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

# C) STOP/START: write once with exec, restart the same container, then read with
#    exec so the long-running container command cannot rewrite the file.
# TODO 4 (13.2): prove the file survives stop/start but not remove/recreate.
docker run -d --name "$LIFE_CONTAINER" busybox sleep 300 >/dev/null
docker exec "$LIFE_CONTAINER" sh -c 'echo hi > /lifecycle.txt'
docker stop "$LIFE_CONTAINER" >/dev/null
docker start "$LIFE_CONTAINER" >/dev/null
after_restart=$(docker exec "$LIFE_CONTAINER" cat /lifecycle.txt)
docker rm -f "$LIFE_CONTAINER" >/dev/null
docker run -d --name "$LIFE_CONTAINER" busybox sleep 300 >/dev/null
after_recreate=$(docker exec "$LIFE_CONTAINER" sh -c 'cat /lifecycle.txt 2>/dev/null || echo GONE')

# D) DISK USAGE: read the Local Volumes row from structured docker system df
#    output. The count is machine-dependent; only its readable presence matters.
# TODO 5 (13.4): extract the total volume count.
volume_df_count=$(docker system df --format '{{.Type}}|{{.TotalCount}}' | awk -F'|' '$1 == "Local Volumes" {print $2}')

{
  echo "ephemeral=$ephemeral"
  echo "persisted=$persisted"
  echo "vol_exists=$vol_exists"
  echo "after_restart=$after_restart"
  echo "after_recreate=$after_recreate"
  echo "volume_df_count=$volume_df_count"
} > "$OUT/data.txt"
