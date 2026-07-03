#!/usr/bin/env bash
set -euo pipefail

# Chapter 4 solution — dissect an OCI image by hand.
# Needs Docker for pull/save. The overlay mount runs directly when root,
# or inside a user namespace (unshare -Urm, kernel >= 5.11) otherwise.

IMAGE=alpine:3

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/lab-cap04.XXXXXX")
cleanup() {
  if mountpoint -q "$WORKDIR/merged" 2>/dev/null; then
    umount "$WORKDIR/merged" || true
  fi
  chmod -R u+rwX "$WORKDIR" 2>/dev/null || true
  rm -rf "$WORKDIR"
}
trap cleanup EXIT
cd "$WORKDIR"

echo "== 1. The image laid bare =="
docker pull -q "$IMAGE" >/dev/null
docker save "$IMAGE" -o image.tar
mkdir image && tar -xf image.tar -C image
find image -type f | sort

echo
echo "== 2. The chain: manifest -> config -> layer =="
cat image/manifest.json
echo
LAYER=$(grep -o '"Layers":\["[^"]*"' image/manifest.json | cut -d'"' -f4)
echo "layer blob: $LAYER"

echo
echo "== 3. The layer is just a filesystem tarball =="
mkdir layer && tar -xf "image/$LAYER" -C layer
ls layer

echo
echo "== 4. Overlay by hand: copy-on-write in action =="
mkdir upper work merged
DEMO='
mount -t overlay overlay -o lowerdir=layer,upperdir=upper,workdir=work merged
echo "modified from the container" > merged/etc/motd
rm merged/etc/hostname
echo "--- upper/etc (the container layer): a copy and a whiteout ---"
ls -l upper/etc/
echo "--- the lower layer is untouched ---"
ls layer/etc/hostname
head -1 layer/etc/motd 2>/dev/null || echo "(layer/etc/motd empty, as shipped)"
umount merged
rm -rf upper work
'
if [ "$(id -u)" -eq 0 ]; then
  sh -c "$DEMO"
else
  echo "(not root: mounting inside a user namespace, see the brief's box)"
  unshare -Urm sh -c "$DEMO"
fi

echo
echo "== 5. Root in the container is not root on the host =="
echo "--- CapEff inside the container ---"
docker run --rm "$IMAGE" grep CapEff /proc/self/status
echo "--- CapEff of host PID 1 ---"
grep CapEff /proc/1/status
echo "--- trying to set the clock inside (must be refused) ---"
set +e
OUT=$(docker run --rm "$IMAGE" date -s "2000-01-01" 2>&1)
set -e
echo "$OUT"
if echo "$OUT" | grep -q "not permitted"; then
  echo "refused as expected: CAP_SYS_TIME is missing"
  echo "(note: busybox date still exits 0 — the refusal is in the message)"
fi

echo
echo "== 6. One kernel, shared =="
echo "host:      $(uname -r)"
echo "container: $(docker run --rm "$IMAGE" uname -r)"
