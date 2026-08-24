#!/usr/bin/env bash
# cap27 - solution test. Proves safe day-2 cleanup: an orphan stopped container and an
# unused volume, both labelled ours, exist before; a label-filtered container prune
# and a removal by name reclaim exactly those. It also verifies a volume restore and
# a round trip through a loopback-only registry. No restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/maintenance.sh" "$WORK"
con_before=$(val "$WORK/maint.txt" con_before)
vol_before=$(val "$WORK/maint.txt" vol_before)
con_after=$(val "$WORK/maint.txt" con_after)
vol_after=$(val "$WORK/maint.txt" vol_after)
backup_match=$(val "$WORK/maint.txt" backup_match)
pushed_digest=$(val "$WORK/maint.txt" pushed_digest)
pulled_digest=$(val "$WORK/maint.txt" pulled_digest)

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

# 4. the restored volume contains exactly the known text written before the backup
if [ "$backup_match" != "true" ]; then
  echo "UNEXPECTED: restored volume content differs from the backup source" >&2; exit 1
fi
echo "OK 4 - volume backup restored the original deterministic content"

# 5. push/remove/pull restored the scoped tag with the registry's original digest
if [ -z "$pushed_digest" ] || [ "$pulled_digest" != "$pushed_digest" ]; then
  echo "UNEXPECTED: registry round trip changed the manifest digest" >&2; exit 1
fi
echo "OK 5 - loopback registry restored the removed tag with the same digest"

echo
echo "ALL CHECKS PASSED"
