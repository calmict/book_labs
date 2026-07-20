#!/usr/bin/env bash
# cap23 solution - "king only in his own room": the rootless privilege model. In a
# USER namespace that maps you to root you are uid 0 with a full capability set, but
# that root is mapped to your real, unprivileged host user - a file it creates is
# owned by your UID on the host, and it cannot write the host's root-owned files.
# No privileges, no Docker, no daemon: just unshare, run as an ordinary user.
set -euo pipefail

OUT="${1:?usage: irootless.sh OUTPUT_DIR}"
mkdir -p "$OUT"
outer_uid=$(id -u)

# TODO 1 (23.2): inside a user namespace mapping you to root, read the uid (0).
inner_uid=$(unshare --user --map-root-user id -u)

# TODO 2 (23.3): create a file "as root" inside the userns; read its host owner.
unshare --user --map-root-user sh -c "touch '$OUT/asroot'"
owner_uid=$(stat -c '%u' "$OUT/asroot")

# TODO 3 (23.3): can that "root" write to a host root-owned path (/etc)? (no)
host_write=$(unshare --user --map-root-user sh -c 'touch /etc/rootless-probe 2>/dev/null && echo YES || echo NO')

{
  echo "outer_uid=$outer_uid"
  echo "inner_uid=$inner_uid"
  echo "owner_uid=$owner_uid"
  echo "host_write=$host_write"
} > "$OUT/rootless.txt"
