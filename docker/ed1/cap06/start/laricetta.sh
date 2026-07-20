#!/usr/bin/env bash
# cap06 start - build and run an OCI container by hand with runc, no Docker in the
# loop. Rootless (a --rootless spec). Three gaps to fill (TODO 1..3). As written
# no recipe is generated and nothing runs.
set -euo pipefail

OUT="${1:?usage: laricetta.sh OUTPUT_DIR}"
mkdir -p "$OUT"

BUNDLE=$(mktemp -d)
cleanup() { rm -rf "$BUNDLE"; }
trap cleanup EXIT
cd "$BUNDLE"
mkdir -p rootfs

# A minimal rootfs, borrowed from busybox (from here on Docker is not involved).
cid=$(docker create busybox)
docker export "$cid" | tar -C rootfs -xf -
docker rm "$cid" >/dev/null

# TODO 1 (6.3): generate the runtime-spec recipe, ROOTLESS (a USER namespace and
#   a uid mapping, so no sudo). Then record the namespaces it lists:
#     runc spec --rootless
#     python3 -c "import json;print('namespaces='+','.join(n['type'] for n in json.load(open('config.json'))['linux']['namespaces']))" > "$OUT/oci.txt"
: > "$OUT/oci.txt"

run_recipe() {  # $1 = the word to echo ; edits the recipe, runs it, prints output
  # TODO 2 (6.3): edit the recipe - set the process args to echo "$1" and turn the
  #   terminal off (no tty, so the output is captured on stdout):
  #     python3 - "$1" <<'PY'
  #     import json, sys
  #     c = json.load(open('config.json'))
  #     c['process']['args'] = ['/bin/echo', sys.argv[1]]
  #     c['process']['terminal'] = False
  #     json.dump(c, open('config.json', 'w'))
  #     PY

  # TODO 3 (6.3): run the bundle with runc and let it print the container output:
  #     runc --root "$BUNDLE/state" run "oci-$1"
  true
}

echo "run_one=$(run_recipe ricetta-uno)" >> "$OUT/oci.txt"
echo "run_two=$(run_recipe ricetta-due)" >> "$OUT/oci.txt"
