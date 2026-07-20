#!/usr/bin/env bash
# cap13 - solution test. Proves the lifecycle of data: a file written to the
# container's writable layer is gone from a fresh container (ephemeral); a file
# written to a named volume is read back after the writing container is removed
# (persistent); and the volume still exists with no container using it. Throwaway
# containers, uniquely named volume, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/aterra.sh" "$WORK"
ephemeral=$(val "$WORK/data.txt" ephemeral)
persisted=$(val "$WORK/data.txt" persisted)
vol_exists=$(val "$WORK/data.txt" vol_exists)

# 1. the container's writable layer is ephemeral: a fresh container has no file
if [ "$ephemeral" != "GONE" ]; then
  echo "UNEXPECTED: a fresh container saw the file (ephemeral=$ephemeral), expected GONE" >&2; exit 1
fi
echo "OK 1 - the container layer is ephemeral: the file is GONE in a fresh container"

# 2. the named volume persists across the container's removal
if [ "$persisted" != "hi" ]; then
  echo "UNEXPECTED: the volume did not persist (persisted=$persisted), expected hi" >&2; exit 1
fi
echo "OK 2 - the named volume persists: read back 'hi' from a new container"

# 3. the volume has its own lifecycle: it exists with no container using it
if [ "$vol_exists" != "1" ]; then
  echo "UNEXPECTED: the volume is not present as a first-class object (vol_exists=$vol_exists)" >&2; exit 1
fi
echo "OK 3 - the volume is a first-class object: still present with no container attached"

echo
echo "ALL CHECKS PASSED"
