#!/usr/bin/env bash
# cap23 solution - "king only in his own room": the rootless privilege model. In a
# USER namespace that maps you to root you are uid 0 with a full capability set, but
# that root is mapped to your real, unprivileged host user - a file it creates is
# owned by your UID on the host, and it cannot write the host's root-owned files.
# The final contrast uses a read-only host mount through the rootful Docker daemon.
set -euo pipefail

OUT="${1:?usage: rootless.sh OUTPUT_DIR}"
mkdir -p "$OUT"
outer_uid=$(id -u)
outer_gid=$(id -g)

# TODO 1 (23.2): inside a user namespace mapping you to root, read the uid (0).
inner_uid=$(unshare --user --map-root-user id -u)

# TODO 2 (23.3): create a file "as root" inside the userns; read its host owner.
unshare --user --map-root-user sh -c "touch '$OUT/asroot'"
owner_uid=$(stat -c '%u' "$OUT/asroot")

# TODO 3 (23.3): can that "root" write to a host root-owned path (/etc)? (no)
host_write=$(unshare --user --map-root-user sh -c 'touch /etc/rootless-probe 2>/dev/null && echo YES || echo NO')

IMAGE="busybox"
ROOT_CONTAINER="cap23-host-root-$$"
USER_CONTAINER="cap23-host-user-$$"
cleanup() {
  docker rm -f "$ROOT_CONTAINER" "$USER_CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# The probe path: the first root-owned path your own user cannot read. It is read,
# never written, and never a credentials file - only the fact that it opens.
probe=""
for candidate in /root /var/lib/docker; do
  if [ -e "$candidate" ] && ! ls -A "$candidate" >/dev/null 2>&1; then
    probe="$candidate"
    break
  fi
done

# TODO 4 (23.1): your user is denied; the daemon, asked for uid 0, is not.
direct_read=$(ls -A "$probe" >/dev/null 2>&1 && echo YES || echo NO)
root_probe=$(docker run --rm --name "$ROOT_CONTAINER" -v /:/host:ro "$IMAGE" sh -c \
  'printf "%s:%s:%s:" "$(id -u)" "$(stat -c %u "/host$1")" "$(stat -c %a "/host$1")"; ls -A "/host$1" >/dev/null 2>&1 && echo YES || echo NO' \
  sh "$probe")

# TODO 5 (23.4): the same image and the same mount, as the unprivileged host uid.
user_read=$(docker run --rm --name "$USER_CONTAINER" --user "$outer_uid:$outer_gid" \
  -v /:/host:ro "$IMAGE" sh -c 'ls -A "/host$1" >/dev/null 2>&1 && echo YES || echo NO' sh "$probe")

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
