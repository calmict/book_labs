#!/usr/bin/env bash
# Chapter 4 start - inspect an OCI image, exercise OverlayFS copy-on-write,
# and compare the container with its host. This file is valid but incomplete.
set -euo pipefail

OUT=${1:?usage: image-lab.sh OUTPUT_DIR}
IMAGE=${CAP04_IMAGE:-alpine:3}
mkdir -p "$OUT/image" "$OUT/layer"

docker pull -q "$IMAGE" >/dev/null
docker save "$IMAGE" -o "$OUT/image.tar"
tar -xf "$OUT/image.tar" -C "$OUT/image"

# TODO 1 (4.2): follow manifest.json to the config and first layer paths.
# Write config_path and layer_path to image.env so later steps inspect the
# objects selected by the manifest rather than guessing blob names.
: > "$OUT/image.env"

# TODO 2 (4.1): extract the selected layer, mount it below a writable OverlayFS,
# modify etc/motd, delete etc/hostname, and record proof that lower stayed
# unchanged while the merged view changed. Use a user namespace, not sudo.
: > "$OUT/overlay.env"

# TODO 3 (4.3, 4.4): record the container and host CapEff masks, the refusal
# from date -s, and uname -r on both sides. These observations prove that uid 0
# lacks CAP_SYS_TIME and that the kernel is shared.
: > "$OUT/isolation.env"
