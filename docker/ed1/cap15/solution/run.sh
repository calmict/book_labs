#!/usr/bin/env bash
# cap15 - solution test. Proves UID/GID permissions on a shared mount are by
# number: a container whose UID does not own the bind-mounted folder is denied
# the write; the same container run as the owning UID writes; and the created
# file is owned, on the host, by that same UID (no translation across the mount).
# Throwaway containers, a temp folder, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
# A root container may have left root-owned files on the mount: the tidy-up that
# the host user cannot do is done from inside a container, never with sudo.
cleanup() {
  docker run --rm -v "$WORK:/w" busybox sh -c 'rm -rf /w/* /w/.[!.]* 2>/dev/null || true' >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/ipermessi.sh" "$WORK"
host_uid=$(val "$WORK/perms.txt" host_uid)
mismatch=$(val "$WORK/perms.txt" mismatch)
match=$(val "$WORK/perms.txt" match)
owner_uid=$(val "$WORK/perms.txt" owner_uid)
root_owner=$(val "$WORK/perms.txt" root_owner)
host_cleanup=$(val "$WORK/perms.txt" host_cleanup)
user_write=$(val "$WORK/perms.txt" user_write)
user_owner=$(val "$WORK/perms.txt" user_owner)
entry_uid=$(val "$WORK/perms.txt" entry_uid)
entry_owner=$(val "$WORK/perms.txt" entry_owner)
after_cure=$(val "$WORK/perms.txt" after_cure)

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

# 4. the problem: a container left as root leaves a tree the user cannot remove
if [ "$root_owner" != "0" ]; then
  echo "UNEXPECTED: the root container's file is owned by UID $root_owner, expected 0" >&2; exit 1
fi
if [ "$host_cleanup" != "DENIED" ]; then
  echo "UNEXPECTED: the host user removed the root-owned tree ($host_cleanup)" >&2; exit 1
fi
echo "OK 4 - the root problem: the tree belongs to UID $root_owner on the host, and removing it is $host_cleanup"

# 5. cure 1 (15.2): USER declared in the image, no flag needed at run
if [ "$user_write" != "WROTE" ] || [ "$user_owner" != "$host_uid" ]; then
  echo "UNEXPECTED: the USER image wrote '$user_write' and the file is owned by $user_owner," >&2
  echo "            expected WROTE and $host_uid" >&2; exit 1
fi
echo "OK 5 - cure, USER in the image: writes with no --user flag, and the file is yours (UID $user_owner)"

# 6. cure 2 (15.3): root fixes the ownership, then hands the process over
if [ "$entry_uid" != "$host_uid" ]; then
  echo "UNEXPECTED: after the handover the process runs as UID $entry_uid, expected $host_uid" >&2; exit 1
fi
if [ "$entry_owner" != "$host_uid" ] || [ "$after_cure" != "REMOVED" ]; then
  echo "UNEXPECTED: the file left behind is owned by $entry_owner and the tidy-up was $after_cure," >&2
  echo "            expected $host_uid and REMOVED" >&2; exit 1
fi
echo "OK 6 - cure, entrypoint: root fixes the ownership then drops to UID $entry_uid, what it writes is yours,"
echo "       and the tree root had locked is now $after_cure by the plain user"

echo
echo "ALL CHECKS PASSED"
