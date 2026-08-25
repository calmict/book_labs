#!/usr/bin/env bash
# cap06 solution - "the OCI recipe": build and run an OCI container by hand with
# runc, no Docker in the loop. Generate a config.json (the runtime-spec recipe),
# read the Part 1 mechanisms listed inside it, run it, then change the recipe and
# watch the container change, change its UTS namespace, and run the same bundle
# with two OCI runtimes. Rootless: a --rootless spec (USER namespace, uid
# mapping), so no sudo.
set -euo pipefail

OUT="${1:?usage: recipe.sh OUTPUT_DIR}"
mkdir -p "$OUT"

BUNDLE=$(mktemp -d -t cap06-bundle.XXXXXX)
cid=""
cleanup() {
  if [ -n "$cid" ]; then
    docker rm -f "$cid" >/dev/null 2>&1 || true
  fi
  rm -rf "$BUNDLE"
}
trap cleanup EXIT
cd "$BUNDLE"
mkdir -p rootfs

# A minimal rootfs. We borrow busybox's filesystem via docker export - but note
# that from here on Docker is not involved: runc runs the bundle on its own.
container_name="cap06-rootfs-${BUNDLE##*.}"
cid=$(docker create --name "$container_name" busybox)
docker export "$cid" | tar -C rootfs -xf -
docker rm "$cid" >/dev/null
cid=""

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

# Give the recipe a private UTS namespace and a hostname guaranteed to differ
# from the current host, then execute /bin/hostname inside the container.
host_hostname=$(hostname)
recipe_hostname="cap06-recipe-host"
if [ "$recipe_hostname" = "$host_hostname" ]; then
  recipe_hostname="cap06-recipe-host-private"
fi
python3 - "$recipe_hostname" <<'PY'
import json, sys
c = json.load(open('config.json'))
c['process']['args'] = ['/bin/hostname']
c['process']['terminal'] = False
c['hostname'] = sys.argv[1]
json.dump(c, open('config.json', 'w'))
PY
echo "recipe_hostname=$recipe_hostname" >> "$OUT/oci.txt"
echo "uts_private=$(runc --root "$BUNDLE/state-uts-private" run oci-uts-private)" >> "$OUT/oci.txt"

# A hostname can only be set with a private UTS namespace. Remove both parts of
# that contract; /bin/hostname now observes the host UTS namespace.
python3 - <<'PY'
import json
c = json.load(open('config.json'))
c['linux']['namespaces'] = [n for n in c['linux']['namespaces'] if n['type'] != 'uts']
c.pop('hostname', None)
json.dump(c, open('config.json', 'w'))
PY
echo "uts_host=$(runc --root "$BUNDLE/state-uts-host" run oci-uts-host)" >> "$OUT/oci.txt"

# The bundle and recipe stay unchanged: only the conforming OCI runtime changes.
runtime2=${CAP06_RUNTIME2:-crun}
python3 - <<'PY'
import json
c = json.load(open('config.json'))
c['process']['args'] = ['/bin/echo', 'same-oci-recipe']
c['process']['terminal'] = False
json.dump(c, open('config.json', 'w'))
PY
echo "runtime_runc=$(runc --root "$BUNDLE/state-runtime-runc" run oci-runtime-runc)" >> "$OUT/oci.txt"
echo "runtime_two=$("$runtime2" --root "$BUNDLE/state-runtime-two" run oci-runtime-two)" >> "$OUT/oci.txt"
