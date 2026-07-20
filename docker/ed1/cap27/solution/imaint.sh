#!/usr/bin/env bash
# cap27 solution - "clean the hold": safe day-2 maintenance. It creates an orphan
# stopped container and an unused volume, both labelled as ours, then reclaims them
# by scope only - a label-filtered container prune and a removal by name - never a
# global prune that would delete other people's resources on a shared daemon.
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

# TODO 1 (27.2): reclaim ONLY our stopped containers (scoped by label, never global).
docker container prune -f --filter "label=owner=$LABEL" >/dev/null

# TODO 2 (27.2): reclaim our named volume explicitly.
docker volume rm "$VOL" >/dev/null

# TODO 3 (27.2): recount - nothing of ours should remain.
con_after=$(docker ps -aq --filter "label=owner=$LABEL" | grep -c . || true)
vol_after=$(docker volume ls -q --filter "label=owner=$LABEL" | grep -c . || true)

{
  echo "con_before=$con_before"
  echo "vol_before=$vol_before"
  echo "con_after=$con_after"
  echo "vol_after=$vol_after"
} > "$OUT/maint.txt"
