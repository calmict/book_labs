#!/usr/bin/env bash
# cap23 - solution test. Proves the rootless privilege model: inside a USER
# namespace you are uid 0 ("root"), but that root maps to your real unprivileged
# host user (a file it creates is owned by your UID, not 0), and it cannot write the
# host's root-owned files, then contrasts direct /root access with daemon access.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

if [ "$(id -u)" = "0" ]; then
  echo "ERROR: run this exercise as an unprivileged user, not as root" >&2; exit 1
fi
command -v unshare >/dev/null || { echo "ERROR: unshare not found (util-linux, see SETUP.md)" >&2; exit 1; }
if ! unshare --user --map-root-user true 2>/dev/null; then
  echo "ERROR: unprivileged user namespaces are not available on this host" >&2; exit 1
fi
command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md; membership in the docker group is required)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/rootless.sh" "$WORK"
outer_uid=$(val "$WORK/rootless.txt" outer_uid)
inner_uid=$(val "$WORK/rootless.txt" inner_uid)
owner_uid=$(val "$WORK/rootless.txt" owner_uid)
host_write=$(val "$WORK/rootless.txt" host_write)
probe=$(val "$WORK/rootless.txt" probe)
direct_read=$(val "$WORK/rootless.txt" direct_read)
root_probe=$(val "$WORK/rootless.txt" root_probe)
user_read=$(val "$WORK/rootless.txt" user_read)
IFS=: read -r container_uid probe_owner_uid probe_mode probe_read <<< "$root_probe"

if [ -z "$probe" ]; then
  echo "ERROR: no root-owned path closed to your user was found on this host, so the contrast cannot be measured" >&2; exit 1
fi

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

# 4. direct access is denied, but daemon-selected uid 0 reads the read-only mount
if [ "$outer_uid" = "0" ] || [ "$direct_read" != "NO" ]; then
  echo "UNEXPECTED: the unprivileged host user could read $probe (uid=$outer_uid read=$direct_read)" >&2; exit 1
fi
if [ "$container_uid" != "0" ] || [ "$probe_owner_uid" != "0" ] || [ "$probe_read" != "YES" ]; then
  echo "UNEXPECTED: daemon root probe uid=$container_uid owner=$probe_owner_uid mode=$probe_mode read=$probe_read" >&2; exit 1
fi
echo "OK 4 - host uid $outer_uid is denied on $probe (root-owned, mode $probe_mode), daemon-selected uid 0 reads it"

# 5. the identical read-only mount is denied when the daemon uses the host uid
if [ "$user_read" != "NO" ]; then
  echo "UNEXPECTED: container uid $outer_uid could read $probe through the read-only mount" >&2; exit 1
fi
echo "OK 5 - the same read-only mount denies container uid $outer_uid: the decisive difference is uid 0"

echo
echo "ALL CHECKS PASSED"
