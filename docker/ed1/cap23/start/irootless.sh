#!/usr/bin/env bash
# cap23 start - the rootless privilege model, to complete. Three gaps (TODO 1..3):
# the uid inside the userns, the host owner of a file created "as root", and whether
# that root can write host root-owned files are missing, so the measurements are
# empty and the test fails. No privileges, no Docker: just unshare.
set -euo pipefail

OUT="${1:?usage: irootless.sh OUTPUT_DIR}"
mkdir -p "$OUT"
outer_uid=$(id -u)

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

{
  echo "outer_uid=$outer_uid"
  echo "inner_uid=$inner_uid"
  echo "owner_uid=$owner_uid"
  echo "host_write=$host_write"
} > "$OUT/rootless.txt"
