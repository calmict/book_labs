#!/usr/bin/env bash
# cap23 start - the rootless privilege model, to complete. Five gaps (TODO 1..5):
# the uid inside the userns, the host owner of a file created "as root", and whether
# that root can write host root-owned files are missing, so the measurements are
# empty and the test fails. The final gaps safely contrast Docker daemon identities.
set -euo pipefail

OUT="${1:?usage: rootless.sh OUTPUT_DIR}"
mkdir -p "$OUT"
outer_uid=$(id -u)
outer_gid=$(id -g)

# TODO 1 (23.2): inside a user namespace mapping you to root, read the uid (0):
#     inner_uid=$(unshare --user --map-root-user id -u)
inner_uid=""

# TODO 2 (23.3): create a file "as root" inside the userns; read its host owner:
#     unshare --user --map-root-user sh -c "touch '$OUT/asroot'"
#     owner_uid=$(stat -c '%u' "$OUT/asroot")
owner_uid=""

# TODO 3 (23.3): can that "root" write to a host root-owned path (/etc)?
#     host_write=$(unshare --user --map-root-user sh -c 'touch /etc/rootless-probe 2>/dev/null && echo YES || echo NO')
host_write=""

IMAGE="busybox"
ROOT_CONTAINER="cap23-host-root-$$"
USER_CONTAINER="cap23-host-user-$$"
cleanup() {
  docker rm -f "$ROOT_CONTAINER" "$USER_CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Given: the probe path is the first root-owned path your own user cannot read.
# It is only ever read, never written, and it is never a credentials file.
probe=""
for candidate in /root /var/lib/docker; do
  if [ -e "$candidate" ] && ! ls -A "$candidate" >/dev/null 2>&1; then
    probe="$candidate"
    break
  fi
done

# TODO 4 (23.1): your user is denied on that path; the daemon, asked for uid 0, is
# not. Read both sides - the direct attempt, and the same path from inside a
# container that mounts the host root READ-ONLY (print only whether it opened):
#     direct_read=$(ls -A "$probe" >/dev/null 2>&1 && echo YES || echo NO)
#     root_probe=$(docker run --rm --name "$ROOT_CONTAINER" -v /:/host:ro "$IMAGE" sh -c \
#       'printf "%s:%s:%s:" "$(id -u)" "$(stat -c %u "/host$1")" "$(stat -c %a "/host$1")"; ls -A "/host$1" >/dev/null 2>&1 && echo YES || echo NO' \
#       sh "$probe")
direct_read=""
root_probe=""

# TODO 5 (23.4): the same image and the same read-only mount, but asking the daemon
# for your own unprivileged uid instead of uid 0:
#     user_read=$(docker run --rm --name "$USER_CONTAINER" --user "$outer_uid:$outer_gid" \
#       -v /:/host:ro "$IMAGE" sh -c 'ls -A "/host$1" >/dev/null 2>&1 && echo YES || echo NO' sh "$probe")
user_read=""

{
  echo "outer_uid=$outer_uid"
  echo "inner_uid=$inner_uid"
  echo "owner_uid=$owner_uid"
  echo "host_write=$host_write"
  echo "probe=$probe"
  echo "direct_read=$direct_read"
  echo "root_probe=$root_probe"
  echo "user_read=$user_read"
} > "$OUT/rootless.txt"
