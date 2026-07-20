#!/usr/bin/env bash
# cap15 solution - "the number on the badge": UID/GID permissions on a shared
# mount. A host folder is owned by the current UID (mode 755). A container run
# with a different non-root UID is refused when it writes to the bind mount
# (mismatch); the same container run as the owning UID writes fine (cure); and
# the file it creates is owned, on the host, by that same UID (no translation).
# Throwaway containers (--rm), a temp folder: no privileges, no restart.
set -euo pipefail

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

{
  echo "host_uid=$HOST_UID"
  echo "mismatch=$mismatch"
  echo "match=$match"
  echo "owner_uid=$owner_uid"
} > "$OUT/perms.txt"
