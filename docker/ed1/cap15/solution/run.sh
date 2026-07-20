#!/usr/bin/env bash
# cap15 - solution test. Proves UID/GID permissions on a shared mount are by
# number: a container whose UID does not own the bind-mounted folder is denied
# the write; the same container run as the owning UID writes; and the created
# file is owned, on the host, by that same UID (no translation across the mount).
# Throwaway containers, a temp folder, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/ipermessi.sh" "$WORK"
host_uid=$(val "$WORK/perms.txt" host_uid)
mismatch=$(val "$WORK/perms.txt" mismatch)
match=$(val "$WORK/perms.txt" match)
owner_uid=$(val "$WORK/perms.txt" owner_uid)

# 1. mismatch: a UID that does not own the folder cannot write
if [ "$mismatch" != "DENIED" ]; then
  echo "UNEXPECTED: a non-owning UID was allowed to write (mismatch=$mismatch)" >&2; exit 1
fi
echo "OK 1 - mismatch: a container UID that does not own the folder is DENIED"

# 2. cure: the same write as the owning UID goes through
if [ "$match" != "WROTE" ]; then
  echo "UNEXPECTED: the owning UID could not write (match=$match)" >&2; exit 1
fi
echo "OK 2 - cure: running as the owning UID ($host_uid) writes (WROTE)"

# 3. no translation: the created file is owned on the host by that same UID
if [ "$owner_uid" != "$host_uid" ]; then
  echo "UNEXPECTED: the file is owned by UID $owner_uid, expected $host_uid" >&2; exit 1
fi
echo "OK 3 - no translation: the file is owned on the host by UID $owner_uid (= container UID)"

echo
echo "ALL CHECKS PASSED"
