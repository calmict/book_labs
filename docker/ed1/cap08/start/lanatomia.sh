#!/usr/bin/env bash
# cap08 start - anatomy of an image. Builds a small image (busybox + two
# filesystem-changing instructions) and should record its anatomy, but the three
# key measurements are missing. Throwaway images, no restart, no privileges.
# Three gaps to fill (TODO 1..3). As written the measurements are empty and the
# test fails.
set -euo pipefail

OUT="${1:?usage: lanatomia.sh OUTPUT_DIR}"
mkdir -p "$OUT"
TAG="cap08-$$"
BASE="busybox"
cleanup() { docker rmi -f "$TAG-child" "$TAG" >/dev/null 2>&1 || true; rm -f "$OUT/.p" "$OUT/.c"; }
trap cleanup EXIT

docker build -q -t "$TAG" - >/dev/null <<EOF
FROM $BASE
RUN echo one > /one.txt
RUN echo two > /two.txt
EOF

# TODO 1 (8.2): record the layer count of the image and of the base, from the
#   config (.RootFS.Layers is the rootfs.diff_ids list). Fill in:
#     layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$TAG")
#     base_layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$BASE")
layers=""
base_layers=""

# TODO 2 (8.3): record the image ID (sha256 digest of the config) and the digest
#   of the top layer - both are content addresses. Fill in:
#     image_id=$(docker image inspect -f '{{.Id}}' "$TAG")
#     top_layer=$(docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG" | grep '^sha256' | tail -1)
image_id=""
top_layer=""

# TODO 3 (8.4): build a child image on top of the first and count how many of the
#   first's layers reappear identical in the child. Fill in:
#     docker build -q -t "$TAG-child" - >/dev/null <<CHILD
#     FROM $TAG
#     RUN echo three > /three.txt
#     CHILD
#     child_layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$TAG-child")
#     docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG" | grep '^sha256' | sort > "$OUT/.p"
#     docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG-child" | grep '^sha256' | sort > "$OUT/.c"
#     shared=$(comm -12 "$OUT/.p" "$OUT/.c" | grep -c .)
child_layers=""
shared=""

{
  echo "layers=$layers"
  echo "base_layers=$base_layers"
  echo "image_id=$image_id"
  echo "top_layer=$top_layer"
  echo "child_layers=$child_layers"
  echo "shared=$shared"
} > "$OUT/image.txt"
