#!/usr/bin/env bash
# cap08 - solution test. Proves an image is a config plus a stack of layers: it
# has one layer per filesystem-changing instruction (base + 2 RUNs), it is
# identified by a sha256 content digest (image ID) whose layers are themselves
# digests, and a child image built on top reuses all of its layers - shared, not
# copied. Throwaway images, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/lanatomia.sh" "$WORK"
layers=$(val "$WORK/image.txt" layers)
base_layers=$(val "$WORK/image.txt" base_layers)
image_id=$(val "$WORK/image.txt" image_id)
top_layer=$(val "$WORK/image.txt" top_layer)
child_layers=$(val "$WORK/image.txt" child_layers)
shared=$(val "$WORK/image.txt" shared)

# 1. one layer per filesystem-changing instruction: base + 2 RUNs
if [ "$layers" != "$(( base_layers + 2 ))" ]; then
  echo "UNEXPECTED: image has $layers layers, expected base ($base_layers) + 2" >&2; exit 1
fi
echo "OK 1 - the image is a stack: $layers layers = base ($base_layers) + 2 RUNs"

# 2. content-addressed: the image ID and the top layer are sha256 digests
case "$image_id" in sha256:*) ;; *) echo "UNEXPECTED: image ID is not a sha256 digest ($image_id)" >&2; exit 1;; esac
case "$top_layer" in sha256:*) ;; *) echo "UNEXPECTED: top layer is not a sha256 digest ($top_layer)" >&2; exit 1;; esac
echo "OK 2 - content-addressed: image ID and top layer are sha256 digests"

# 3. the child reuses ALL of the first's layers and adds exactly one
if [ "$child_layers" != "$(( layers + 1 ))" ] || [ "$shared" != "$layers" ]; then
  echo "UNEXPECTED: child has $child_layers layers (want $(( layers + 1 ))) and shares $shared (want $layers)" >&2; exit 1
fi
echo "OK 3 - layers are shared: the child reuses all $shared and adds 1 ($child_layers total)"

echo
echo "ALL CHECKS PASSED"
