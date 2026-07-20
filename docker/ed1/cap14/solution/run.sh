#!/usr/bin/env bash
# cap14 - solution test. Proves the trait of each mount type: a bind mount makes
# the container's write appear on the chosen host folder; a named volume persists
# across container removal (read back by a fresh container); a tmpfs mount is of
# type tmpfs (in memory), not persisted and never on disk. Throwaway containers,
# uniquely named volume, temp folder, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/imontaggi.sh" "$WORK"
bind_host=$(val "$WORK/mounts.txt" bind_host)
vol_persist=$(val "$WORK/mounts.txt" vol_persist)
tmpfs_type=$(val "$WORK/mounts.txt" tmpfs_type)

# 1. bind mount: the container's write is visible on the host, at the mounted path
if [ "$bind_host" != "frombind" ]; then
  echo "UNEXPECTED: the host did not see the bind write (bind_host=$bind_host)" >&2; exit 1
fi
echo "OK 1 - bind mount: the container's write appears on the host (bind_host=$bind_host)"

# 2. volume: the write persists, read back by a fresh container
if [ "$vol_persist" != "fromvol" ]; then
  echo "UNEXPECTED: the volume did not persist (vol_persist=$vol_persist)" >&2; exit 1
fi
echo "OK 2 - volume: read back '$vol_persist' from a new container (daemon-managed)"

# 3. tmpfs: the /cache mount is memory-backed (type tmpfs)
if [ "$tmpfs_type" != "TMPFS" ]; then
  echo "UNEXPECTED: /cache is not a tmpfs mount (tmpfs_type=$tmpfs_type)" >&2; exit 1
fi
echo "OK 3 - tmpfs: /cache is an in-memory tmpfs mount (not persisted, not on disk)"

echo
echo "ALL CHECKS PASSED"
