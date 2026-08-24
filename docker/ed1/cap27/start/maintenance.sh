#!/usr/bin/env bash
# cap27 start - safe day-2 maintenance, to complete. The orphan container and volume
# are created; five reclaim, verify, backup and registry operations are missing.
# Five gaps (TODO 1..5) keep the exercise incomplete. Everything is labelled or
# named as ours and removed by scope only; a safety trap cleans up regardless.
set -euo pipefail

OUT="${1:?usage: maintenance.sh OUTPUT_DIR}"
mkdir -p "$OUT"
LABEL="cap27-$$"
CON="cap27con-$$"
VOL="cap27vol-$$"
BACKUP_VOL="cap27backup-$$"
RESTORE_VOL="cap27restore-$$"
ARCHIVE="$OUT/cap27-backup-$$.tgz"
REGISTRY="cap27registry-$$"
REGISTRY_TAG=""
cleanup() {
  docker rm -f "$CON" >/dev/null 2>&1 || true
  docker rm -f "$REGISTRY" >/dev/null 2>&1 || true
  if [ -n "$REGISTRY_TAG" ]; then
    docker image rm "$REGISTRY_TAG" >/dev/null 2>&1 || true
  fi
  docker volume rm -f "$VOL" >/dev/null 2>&1 || true
  docker volume rm -f "$BACKUP_VOL" "$RESTORE_VOL" >/dev/null 2>&1 || true
  rm -f "$ARCHIVE"
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

known_text="cap27 deterministic backup"
backup_match=""
# TODO 4 (27.3): fill a volume, back it up read-only and restore it into a new volume:
#     docker volume create --label "owner=$LABEL" "$BACKUP_VOL" >/dev/null
#     docker run --rm -v "$BACKUP_VOL:/data" busybox sh -c \
#       'printf "%s\n" "$1" > /data/message.txt' sh "$known_text"
#     docker run --rm -v "$BACKUP_VOL:/data:ro" -v "$OUT:/backup" busybox \
#       tar czf "/backup/$(basename "$ARCHIVE")" -C /data .
#     docker volume create --label "owner=$LABEL" "$RESTORE_VOL" >/dev/null
#     docker run --rm -v "$RESTORE_VOL:/data" -v "$OUT:/backup:ro" busybox \
#       tar xzf "/backup/$(basename "$ARCHIVE")" -C /data
#     restored_text=$(docker run --rm -v "$RESTORE_VOL:/data:ro" busybox cat /data/message.txt)
#     if [ "$restored_text" = "$known_text" ]; then
#       backup_match=true
#     fi

pushed_digest=""
pulled_digest=""
# TODO 5 (27.3): run a loopback-only registry, push a scoped tag, remove it and pull it:
#     docker run -d --name "$REGISTRY" --label "owner=$LABEL" \
#       -p 127.0.0.1::5000 registry:2 >/dev/null
#     REG_PORT=$(docker port "$REGISTRY" 5000/tcp | sed 's/.*://')
#     REGISTRY_TAG="127.0.0.1:$REG_PORT/cap27-image:cap27-$$"
#     for _ in $(seq 1 30); do
#       if (exec 3<>"/dev/tcp/127.0.0.1/$REG_PORT") 2>/dev/null; then break; fi
#       sleep 1
#     done
#     docker tag busybox "$REGISTRY_TAG"
#     docker push "$REGISTRY_TAG" >/dev/null
#     push_check_output=$(docker pull "$REGISTRY_TAG" 2>&1)
#     pushed_digest=$(printf '%s\n' "$push_check_output" | sed -n 's/^[Dd]igest: \(sha256:[0-9a-f]*\).*/\1/p' | tail -n 1)
#     docker image rm "$REGISTRY_TAG" >/dev/null
#     pull_output=$(docker pull "$REGISTRY_TAG" 2>&1)
#     pulled_digest=$(printf '%s\n' "$pull_output" | sed -n 's/^[Dd]igest: \(sha256:[0-9a-f]*\).*/\1/p' | tail -n 1)

{
  echo "con_before=$con_before"
  echo "vol_before=$vol_before"
  echo "con_after=$con_after"
  echo "vol_after=$vol_after"
  echo "backup_match=$backup_match"
  echo "pushed_digest=$pushed_digest"
  echo "pulled_digest=$pulled_digest"
} > "$OUT/maint.txt"
