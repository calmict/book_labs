#!/usr/bin/env bash
# cap27 - solution test. Proves safe day-2 cleanup: an orphan stopped container and an
# unused volume, both labelled ours, exist before; a label-filtered container prune
# and a removal by name reclaim exactly those; and afterwards none of ours remains.
# Everything is scoped by label/name - the shared daemon and other resources are never
# touched. No restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/imaint.sh" "$WORK"
con_before=$(val "$WORK/maint.txt" con_before)
vol_before=$(val "$WORK/maint.txt" vol_before)
con_after=$(val "$WORK/maint.txt" con_after)
vol_after=$(val "$WORK/maint.txt" vol_after)

# 1. before: an orphan container and a volume of ours exist
if [ "$con_before" != "1" ] || [ "$vol_before" != "1" ]; then
  echo "UNEXPECTED: orphans not created (con_before=$con_before vol_before=$vol_before)" >&2; exit 1
fi
echo "OK 1 - orphans present before cleanup (1 stopped container, 1 volume)"

# 2. after the scoped prune, our stopped container is gone
if [ "$con_after" != "0" ]; then
  echo "UNEXPECTED: our stopped container was not reclaimed (con_after=$con_after)" >&2; exit 1
fi
echo "OK 2 - label-scoped prune reclaimed our stopped container"

# 3. after the removal by name, our volume is gone
if [ "$vol_after" != "0" ]; then
  echo "UNEXPECTED: our volume was not reclaimed (vol_after=$vol_after)" >&2; exit 1
fi
echo "OK 3 - our named volume reclaimed (scoped cleanup, nothing else touched)"

echo
echo "ALL CHECKS PASSED"
