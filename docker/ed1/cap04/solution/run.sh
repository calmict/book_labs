#!/usr/bin/env bash
# cap04 - solution test. Builds an OverlayFS by hand and proves Copy-on-Write:
# the merged view fuses two lowers; a write to a read-only lower file lands in the
# upper with the lower intact; and a second container (a second upper on the same
# lowers) does not see the first one's write. Rootless (USER + MNT namespace): no
# sudo, no Docker.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/overlay.sh" "$WORK"
merged_files=$(val "$WORK/result.txt" merged_files)
lower_after=$(val "$WORK/result.txt" lower_after)
upper_after=$(val "$WORK/result.txt" upper_after)
container_b_sees=$(val "$WORK/result.txt" container_b_sees)

# 1. the merged view fuses files from both read-only lowers
case "$merged_files" in
  *a.txt*b.txt*|*b.txt*a.txt*) : ;;
  *) echo "UNEXPECTED: merged did not fuse both lowers (saw: $merged_files)" >&2; exit 1 ;;
esac
echo "OK 1 - the merged view fuses both lowers ($merged_files)"

# 2. Copy-on-Write: the lower is intact, the change went to the upper
if [ "$lower_after" != "vengo dal layer basso" ] || [ "$upper_after" != "modificato dal container A" ]; then
  echo "UNEXPECTED: Copy-on-Write failed (lower=$lower_after upper=$upper_after)" >&2
  exit 1
fi
echo "OK 2 - Copy-on-Write: the lower is untouched, the change lives in the upper"

# 3. a second container (same lowers, own upper) does not see the first's write
if [ "$container_b_sees" != "vengo dal layer basso" ]; then
  echo "UNEXPECTED: container B saw container A's change ($container_b_sees)" >&2
  exit 1
fi
echo "OK 3 - a second container on the same lowers is isolated (sees the original, not A's write)"

echo
echo "ALL CHECKS PASSED"
