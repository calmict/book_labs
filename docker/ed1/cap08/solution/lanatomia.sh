#!/usr/bin/env bash
# cap08 solution - "anatomy of an image": build a small image (busybox + two
# filesystem-changing instructions) and record its anatomy - number of layers,
# the sha256 image ID (config digest), the top layer digest - then build a child
# image on top of it and count how many layers are reused, proving that
# content-addressed layers are shared, not copied. Throwaway images, no restart,
# no privileges: safe anywhere.
set -euo pipefail

OUT="${1:?usage: lanatomia.sh OUTPUT_DIR}"
mkdir -p "$OUT"
TAG="cap08-$$"
BASE="busybox"
cleanup() { docker rmi -f "$TAG-child" "$TAG" >/dev/null 2>&1 || true; rm -f "$OUT/.p" "$OUT/.c"; }
trap cleanup EXIT

# Build the image: from busybox, two RUNs that each write a file -> two layers on
# top of the single busybox base layer.
docker build -q -t "$TAG" - >/dev/null <<EOF
FROM $BASE
RUN echo one > /one.txt
RUN echo two > /two.txt
EOF

# TODO 1 (8.2): record the layer count of the image and of the base, from the
# config (.RootFS.Layers is the rootfs.diff_ids list).
layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$TAG")
base_layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$BASE")

# TODO 2 (8.3): record the image ID (sha256 digest of the config) and the digest
# of the top layer - both are content addresses.
image_id=$(docker image inspect -f '{{.Id}}' "$TAG")
top_layer=$(docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG" | grep '^sha256' | tail -1)

# TODO 3 (8.4): build a child image on top of the first, then count how many of
# the first's layers reappear identical in the child (shared, not duplicated).
docker build -q -t "$TAG-child" - >/dev/null <<EOF
FROM $TAG
RUN echo three > /three.txt
EOF
child_layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$TAG-child")
docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG" | grep '^sha256' | sort > "$OUT/.p"
docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG-child" | grep '^sha256' | sort > "$OUT/.c"
shared=$(comm -12 "$OUT/.p" "$OUT/.c" | grep -c .)

{
  echo "layers=$layers"
  echo "base_layers=$base_layers"
  echo "image_id=$image_id"
  echo "top_layer=$top_layer"
  echo "child_layers=$child_layers"
  echo "shared=$shared"
} > "$OUT/image.txt"
