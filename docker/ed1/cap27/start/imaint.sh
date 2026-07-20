#!/usr/bin/env bash
# cap27 start - safe day-2 maintenance, to complete. The orphan container and volume
# are created; the three reclaim/verify operations are missing. Three gaps
# (TODO 1..3): the scoped prune, the volume removal and the recount are absent, so
# the resources are not reclaimed and the test fails. Everything is labelled ours and
# removed by scope only; a safety trap cleans up regardless.
set -euo pipefail

OUT="${1:?usage: imaint.sh OUTPUT_DIR}"
mkdir -p "$OUT"
LABEL="cap27-$$"
CON="cap27con-$$"
VOL="cap27vol-$$"
cleanup() {
  docker rm -f "$CON" >/dev/null 2>&1 || true
  docker volume rm -f "$VOL" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# an orphan stopped container and an unused volume, both labelled ours
docker run --name "$CON" --label "owner=$LABEL" busybox true >/dev/null
docker volume create --label "owner=$LABEL" "$VOL" >/dev/null

con_before=$(docker ps -aq --filter "label=owner=$LABEL" | grep -c . || true)
vol_before=$(docker volume ls -q --filter "label=owner=$LABEL" | grep -c . || true)

# TODO 1 (27.2): reclaim ONLY our stopped containers (scoped by label, never global):
#     docker container prune -f --filter "label=owner=$LABEL" >/dev/null

# TODO 2 (27.2): reclaim our named volume explicitly:
#     docker volume rm "$VOL" >/dev/null

# TODO 3 (27.2): recount - nothing of ours should remain:
#     con_after=$(docker ps -aq --filter "label=owner=$LABEL" | grep -c . || true)
#     vol_after=$(docker volume ls -q --filter "label=owner=$LABEL" | grep -c . || true)
con_after=""
vol_after=""

{
  echo "con_before=$con_before"
  echo "vol_before=$vol_before"
  echo "con_after=$con_after"
  echo "vol_after=$vol_after"
} > "$OUT/maint.txt"
