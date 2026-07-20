#!/usr/bin/env bash
# cap06 solution - "the OCI recipe": build and run an OCI container by hand with
# runc, no Docker in the loop. Generate a config.json (the runtime-spec recipe),
# read the Part 1 mechanisms listed inside it, run it, then change the recipe and
# watch the container change - proving runc is a faithful executor of config.json.
# Rootless: a --rootless spec (USER namespace, uid mapping), so no sudo.
set -euo pipefail

OUT="${1:?usage: laricetta.sh OUTPUT_DIR}"
mkdir -p "$OUT"

BUNDLE=$(mktemp -d)
cleanup() { rm -rf "$BUNDLE"; }
trap cleanup EXIT
cd "$BUNDLE"
mkdir -p rootfs

# A minimal rootfs. We borrow busybox's filesystem via docker export - but note
# that from here on Docker is not involved: runc runs the bundle on its own.
cid=$(docker create busybox)
docker export "$cid" | tar -C rootfs -xf -
docker rm "$cid" >/dev/null

# Generate the runtime-spec recipe, rootless (a USER namespace + uid mapping).
runc spec --rootless

# The recipe already lists the Part 1 mechanisms as data: record them.
python3 -c "import json;print('namespaces='+','.join(n['type'] for n in json.load(open('config.json'))['linux']['namespaces']))" > "$OUT/oci.txt"

run_recipe() {  # $1 = the word to echo ; edits the recipe, runs it, prints output
  python3 - "$1" <<'PY'
import json, sys
c = json.load(open('config.json'))
c['process']['args'] = ['/bin/echo', sys.argv[1]]
c['process']['terminal'] = False        # no tty: capture on stdout
json.dump(c, open('config.json', 'w'))
PY
  runc --root "$BUNDLE/state" run "oci-$1"
}

# Run the recipe once, then change it and run again: the container follows.
echo "run_one=$(run_recipe ricetta-uno)" >> "$OUT/oci.txt"
echo "run_two=$(run_recipe ricetta-due)" >> "$OUT/oci.txt"
