#!/usr/bin/env bash
# cap13 - solution test. Proves the lifecycle of data: a file written to the
# container's writable layer is gone from a fresh container (ephemeral); a file
# written to a named volume is read back after the writing container is removed
# (persistent); the same writable layer survives stop/start but not removal; and
# docker system df exposes a structured Local Volumes count. Unique resources,
# targeted cleanup, no daemon restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/persistence.sh" "$WORK"
ephemeral=$(val "$WORK/data.txt" ephemeral)
persisted=$(val "$WORK/data.txt" persisted)
vol_exists=$(val "$WORK/data.txt" vol_exists)
after_restart=$(val "$WORK/data.txt" after_restart)
after_recreate=$(val "$WORK/data.txt" after_recreate)
volume_df_count=$(val "$WORK/data.txt" volume_df_count)

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

# 4. stop/start preserves one container's layer; remove/recreate does not
if [ "$after_restart" != "hi" ]; then
  echo "UNEXPECTED: stop/start lost the writable-layer file (after_restart=$after_restart), expected hi" >&2; exit 1
fi
if [ "$after_recreate" != "GONE" ]; then
  echo "UNEXPECTED: a recreated container saw the old writable-layer file (after_recreate=$after_recreate), expected GONE" >&2; exit 1
fi
echo "OK 4 - stop/start preserves the writable layer; remove/recreate makes the file GONE"

# 5. docker system df provides a readable, machine-independent volume count
if ! [[ "$volume_df_count" =~ ^[0-9]+$ ]]; then
  echo "UNEXPECTED: docker system df did not provide a numeric Local Volumes count (volume_df_count=$volume_df_count)" >&2; exit 1
fi
if [ "$volume_df_count" -lt 1 ]; then
  echo "UNEXPECTED: docker system df counted no volumes while the exercise volume exists" >&2; exit 1
fi
echo "OK 5 - docker system df reports a readable Local Volumes count ($volume_df_count)"

echo
echo "ALL CHECKS PASSED"
