#!/usr/bin/env bash
# cap15 start - UID/GID permissions on a shared mount, to complete. Three gaps
# (TODO 1..3): the mismatch write, the matching-UID write and the host-side
# ownership check are missing, so the measurements are empty and the test fails.
# Throwaway containers (--rm), a temp folder.
set -euo pipefail

OUT="${1:?usage: ipermessi.sh OUTPUT_DIR}"
mkdir -p "$OUT"
HOST_UID=$(id -u)
# shellcheck disable=SC2034  # used by TODO 1 once completed
OTHER_UID=12345
HOSTDIR="$OUT/shared"
mkdir -p "$HOSTDIR"
chmod 755 "$HOSTDIR"   # owner rwx, others r-x: only the owner UID may write

# A) MISMATCH: a container whose UID does not own the folder cannot write.
# TODO 1 (15.2): run a container as OTHER_UID and try to write to the mount:
#     mismatch=$(docker run --rm --user "$OTHER_UID" -v "$HOSTDIR:/data" busybox sh -c 'touch /data/x 2>/dev/null && echo WROTE || echo DENIED')
mismatch=""

# B) MATCH: the same write, as the UID that owns the folder, goes through.
# TODO 2 (15.3): run the container as HOST_UID and write:
#     match=$(docker run --rm --user "$HOST_UID" -v "$HOSTDIR:/data" busybox sh -c 'touch /data/ok 2>/dev/null && echo WROTE || echo DENIED')
match=""

# C) The UID crosses the boundary unchanged: the created file is owned by HOST_UID.
# TODO 3 (15.4): from the host, read the owner UID of the created file:
#     owner_uid=$(stat -c '%u' "$HOSTDIR/ok" 2>/dev/null || echo NONE)
owner_uid=""

{
  echo "host_uid=$HOST_UID"
  echo "mismatch=$mismatch"
  echo "match=$match"
  echo "owner_uid=$owner_uid"
} > "$OUT/perms.txt"
