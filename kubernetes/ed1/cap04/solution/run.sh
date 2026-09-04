#!/usr/bin/env bash
# Chapter 4 verification - checks the OCI chain, OverlayFS copy-on-write,
# capability boundary, and shared kernel. The contrast mounts the same lower
# layer read-only and proves that the write then fails. Rootless and throwaway.
# shellcheck disable=SC2154  # variables are assigned by the sourced evidence files
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

"$HERE/image-lab.sh" "$WORK/result"
# shellcheck disable=SC1091
. "$WORK/result/image.env"
# shellcheck disable=SC1091
. "$WORK/result/overlay.env"
# shellcheck disable=SC1091
. "$WORK/result/isolation.env"

test -s "$WORK/result/image/$config_path"
test -s "$WORK/result/image/$layer_path"
jq -e '.config and .rootfs.diff_ids' "$WORK/result/image/$config_path" >/dev/null
echo "OK 1 - the manifest leads to a config and a filesystem layer"

test -d "$WORK/result/layer/etc"
test "$lower_before" = "$lower_after"
test "$upper_motd_present" = yes
test "$merged_hostname_absent" = yes
echo "OK 2 - copy-up and deletion affect the writable layer, not the image layer"

test "$container_cap" != "$host_cap"
test "$clock_refused" -gt 0
echo "OK 3 - container root has fewer capabilities and cannot set the host clock"

test "$host_kernel" = "$container_kernel"
echo "OK 4 - host and container report the same shared kernel"

if CAP04_READ_ONLY=1 "$HERE/image-lab.sh" "$WORK/contrast" >/dev/null 2>&1; then
  echo "UNEXPECTED: the write succeeded without a writable OverlayFS layer" >&2
  exit 1
fi
echo "OK 5 - the gate bites: without upperdir the copy-on-write change is refused"

echo
echo "ALL CHECKS PASSED"
