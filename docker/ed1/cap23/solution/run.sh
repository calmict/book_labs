#!/usr/bin/env bash
# cap23 - solution test. Proves the rootless privilege model: inside a USER
# namespace you are uid 0 ("root"), but that root maps to your real unprivileged
# host user (a file it creates is owned by your UID, not 0), and it cannot write the
# host's root-owned files. No privileges, no Docker, no daemon touched.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v unshare >/dev/null || { echo "ERROR: unshare not found (util-linux, see SETUP.md)" >&2; exit 1; }
if ! unshare --user --map-root-user true 2>/dev/null; then
  echo "ERROR: unprivileged user namespaces are not available on this host" >&2; exit 1
fi

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/irootless.sh" "$WORK"
outer_uid=$(val "$WORK/rootless.txt" outer_uid)
inner_uid=$(val "$WORK/rootless.txt" inner_uid)
owner_uid=$(val "$WORK/rootless.txt" owner_uid)
host_write=$(val "$WORK/rootless.txt" host_write)

# 1. inside the userns you are root (uid 0)
if [ "$inner_uid" != "0" ]; then
  echo "UNEXPECTED: inner uid is '$inner_uid', expected 0" >&2; exit 1
fi
echo "OK 1 - inside the user namespace you are root (uid 0)"

# 2. that root maps to your real, unprivileged user on the host
if [ "$outer_uid" = "0" ] || [ "$owner_uid" != "$outer_uid" ]; then
  echo "UNEXPECTED: root did not map to your unprivileged uid (outer=$outer_uid owner=$owner_uid)" >&2; exit 1
fi
echo "OK 2 - that root maps to your unprivileged host user (uid $owner_uid, not 0)"

# 3. that root cannot write the host's root-owned files
if [ "$host_write" != "NO" ]; then
  echo "UNEXPECTED: the namespace root could write to /etc on the host (host_write=$host_write)" >&2; exit 1
fi
echo "OK 3 - that root cannot write host root-owned files (powerful only inside)"

echo
echo "ALL CHECKS PASSED"
