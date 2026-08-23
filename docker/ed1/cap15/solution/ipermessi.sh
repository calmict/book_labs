#!/usr/bin/env bash
# cap15 solution - "the number on the badge": UID/GID permissions on a shared
# mount. A host folder is owned by the current UID (mode 755). A container run
# with a different non-root UID is refused when it writes to the bind mount
# (mismatch); the same container run as the owning UID writes fine (cure); and
# the file it creates is owned, on the host, by that same UID (no translation).
# Then it reproduces the root-owned files problem - a root container leaves
# behind a tree the unprivileged user cannot touch - and cures it twice: with
# USER declared in the image (15.2) and with an entrypoint that fixes the
# ownership and hands over to the unprivileged user (15.3). Throwaway containers
# (--rm), a temp folder: no privileges on the host, no restart.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
IMG_USER="cap15-user-$$"
IMG_ENTRY="cap15-entry-$$"
trap 'docker rmi -f "$IMG_USER" "$IMG_ENTRY" >/dev/null 2>&1 || true' EXIT

OUT="${1:?usage: ipermessi.sh OUTPUT_DIR}"
mkdir -p "$OUT"
HOST_UID=$(id -u)
OTHER_UID=12345
HOSTDIR="$OUT/shared"
mkdir -p "$HOSTDIR"
chmod 755 "$HOSTDIR"   # owner rwx, others r-x: only the owner UID may write

# A) MISMATCH: a container whose UID does not own the folder cannot write.
# TODO 1 (15.2):
mismatch=$(docker run --rm --user "$OTHER_UID" -v "$HOSTDIR:/data" busybox sh -c 'touch /data/x 2>/dev/null && echo WROTE || echo DENIED')

# B) MATCH: the same write, as the UID that owns the folder, goes through.
# TODO 2 (15.3):
match=$(docker run --rm --user "$HOST_UID" -v "$HOSTDIR:/data" busybox sh -c 'touch /data/ok 2>/dev/null && echo WROTE || echo DENIED')

# C) The UID crosses the boundary unchanged: the created file is owned by HOST_UID.
# TODO 3 (15.4):
owner_uid=$(stat -c '%u' "$HOSTDIR/ok" 2>/dev/null || echo NONE)

# D) THE ROOT PROBLEM: a container left as root writes a whole tree on the mount.
# TODO 4 (15.1):
ROOTDIR="$HOSTDIR/state"
docker run --rm -v "$HOSTDIR:/data" busybox sh -c 'mkdir -p /data/state && echo seed > /data/state/f'
root_owner=$(stat -c '%u' "$ROOTDIR/f")
rm -rf "$ROOTDIR" 2>/dev/null && host_cleanup=REMOVED || host_cleanup=DENIED

# E) CURE 1 (15.2): the identity is declared in the image with USER, no flag at run.
# TODO 5 (15.2):
docker build -q -t "$IMG_USER" --build-arg "APP_UID=$HOST_UID" -f "$HERE/Dockerfile.user" "$HERE" >/dev/null
user_write=$(docker run --rm -v "$HOSTDIR:/data" "$IMG_USER" sh -c 'touch /data/by-user 2>/dev/null && echo WROTE || echo DENIED')
user_owner=$(stat -c '%u' "$HOSTDIR/by-user" 2>/dev/null || echo NONE)

# F) CURE 2 (15.3): root fixes the ownership, then hands over to the plain user.
# TODO 6 (15.3):
docker build -q -t "$IMG_ENTRY" -f "$HERE/Dockerfile.entrypoint" "$HERE" >/dev/null
entry_uid=$(docker run --rm -e "TARGET_UID=$HOST_UID" -v "$HOSTDIR:/data" "$IMG_ENTRY" 'id -u; echo done > /data/state/written' | head -1)
entry_owner=$(stat -c '%u' "$ROOTDIR/written" 2>/dev/null || echo NONE)
rm -rf "$ROOTDIR" 2>/dev/null && after_cure=REMOVED || after_cure=DENIED

{
  echo "host_uid=$HOST_UID"
  echo "mismatch=$mismatch"
  echo "match=$match"
  echo "owner_uid=$owner_uid"
  echo "root_owner=$root_owner"
  echo "host_cleanup=$host_cleanup"
  echo "user_write=$user_write"
  echo "user_owner=$user_owner"
  echo "entry_uid=$entry_uid"
  echo "entry_owner=$entry_owner"
  echo "after_cure=$after_cure"
} > "$OUT/perms.txt"
