#!/usr/bin/env bash
# cap06 start - build and run an OCI container by hand with runc, no Docker in the
# loop. Rootless (a --rootless spec). Five gaps to fill (TODO 1..5). As written
# no recipe is generated and nothing runs.
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

# A minimal rootfs, borrowed from busybox (from here on Docker is not involved).
container_name="cap06-rootfs-${BUNDLE##*.}"
cid=$(docker create --name "$container_name" busybox)
docker export "$cid" | tar -C rootfs -xf -
docker rm "$cid" >/dev/null
cid=""

# TODO 1 (6.3): generate the runtime-spec recipe, ROOTLESS (a USER namespace and
#   a uid mapping, so no sudo). Then record the namespaces it lists:
#     runc spec --rootless
#     python3 -c "import json;print('namespaces='+','.join(n['type'] for n in json.load(open('config.json'))['linux']['namespaces']))" > "$OUT/oci.txt"
: > "$OUT/oci.txt"

run_recipe() {  # $1 = the word to echo ; edits the recipe, runs it, prints output
  # TODO 2 (6.3): edit the recipe - set the process args to echo "$1" and turn the
  #   terminal off (no tty, so the output is captured on stdout). Careful when you
  #   copy this in: the body of a heredoc and its closing PY must start at column
  #   0, even inside an indented function, or bash never sees the end of it:
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

# TODO 4 (6.3): run /bin/hostname with the UTS namespace and a recipe hostname,
#   then remove BOTH the uts entry and hostname (runc rejects a hostname without
#   a private UTS namespace) and run /bin/hostname again. Record the outputs as:
#     host_hostname=$(hostname)
#     recipe_hostname="cap06-recipe-host"
#     if [ "$recipe_hostname" = "$host_hostname" ]; then
#       recipe_hostname="cap06-recipe-host-private"
#     fi
#     python3 - "$recipe_hostname" <<'PY'
#     import json, sys
#     c = json.load(open('config.json'))
#     c['process']['args'] = ['/bin/hostname']
#     c['process']['terminal'] = False
#     c['hostname'] = sys.argv[1]
#     json.dump(c, open('config.json', 'w'))
#     PY
#     echo "recipe_hostname=$recipe_hostname" >> "$OUT/oci.txt"
#     echo "uts_private=$(runc --root "$BUNDLE/state-uts-private" run oci-uts-private)" >> "$OUT/oci.txt"
#     python3 - <<'PY'
#     import json
#     c = json.load(open('config.json'))
#     c['linux']['namespaces'] = [n for n in c['linux']['namespaces'] if n['type'] != 'uts']
#     c.pop('hostname', None)
#     json.dump(c, open('config.json', 'w'))
#     PY
#     echo "uts_host=$(runc --root "$BUNDLE/state-uts-host" run oci-uts-host)" >> "$OUT/oci.txt"

# TODO 5 (6.4): set the recipe command to echo "same-oci-recipe", then run the
#   SAME bundle first with runc and then with "${CAP06_RUNTIME2:-crun}". Use
#   distinct --root directories and record the outputs as:
#     runtime2=${CAP06_RUNTIME2:-crun}
#     python3 - <<'PY'
#     import json
#     c = json.load(open('config.json'))
#     c['process']['args'] = ['/bin/echo', 'same-oci-recipe']
#     c['process']['terminal'] = False
#     json.dump(c, open('config.json', 'w'))
#     PY
#     echo "runtime_runc=$(runc --root "$BUNDLE/state-runtime-runc" run oci-runtime-runc)" >> "$OUT/oci.txt"
#     echo "runtime_two=$("$runtime2" --root "$BUNDLE/state-runtime-two" run oci-runtime-two)" >> "$OUT/oci.txt"
