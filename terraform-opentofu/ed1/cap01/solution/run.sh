#!/usr/bin/env bash
set -euo pipefail

# Chapter 1 solution — the snowflake and the herd: click-ops drift at
# creation time, then the declarative mould at work: idempotence, convergence
# after a night-time hand edit, resurrection after deletion, and a herd
# reborn from code under a new tag.
#
# Runs in a throwaway temp dir so the repo tree stays clean; guaranteed
# cleanup (destroy + rm) on exit. Works with tofu or terraform.

DIR=$(cd "$(dirname "$0")" && pwd)

if command -v tofu >/dev/null 2>&1; then
  TF=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF=terraform
else
  echo "ERROR: neither tofu nor terraform found (see SETUP.md)" >&2
  exit 1
fi

WORK=$(mktemp -d)
cleanup() {
  (cd "$WORK" 2>/dev/null && "$TF" destroy -input=false -auto-approve >/dev/null 2>&1) || true
  rm -rf "$WORK"
}
trap cleanup EXIT

cp "$DIR/main.tf" "$WORK/"
cd "$WORK"

echo "== 0. Click-ops: two 'identical' servers, made by hand =="
printf 'hostname = web-01\npackages = nginx, openssl\nport = 8080\ndebug_mode = off\n' > clickops-a.conf
printf 'hostname = web-02\npackages = nginx\nport = 8080\ndebug_mode = on\n' > clickops-b.conf
echo "  diff between the two hand-made twins:"
diff clickops-a.conf clickops-b.conf | sed 's/^/    /' || true
echo "  (drift was born at CREATION time — every hand-made server is a snowflake)"
echo

echo "== 1. Declare the result: one mould, two identical casts =="
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve -no-color >/dev/null
diff servers/server-a.conf servers/server-b.conf >/dev/null
echo "  server-a.conf and server-b.conf: identical (same mould, no drift possible)"
echo

echo "== 2. Idempotence: apply again, change nothing =="
"$TF" apply -input=false -auto-approve -no-color | grep -E 'No changes|Apply complete' | sed 's/^/  /'
echo

echo "== 3. The 03:12 hand edit (drift), and the convergence =="
printf 'debug_mode = on   # temporary fix, will remove it later (a lie)\n' >> servers/server-b.conf
echo "  hand edit appended: debug_mode = on"
"$TF" plan -input=false -no-color | grep -E '^Plan:' | sed 's/^/  plan says: /'
"$TF" apply -input=false -auto-approve >/dev/null
echo "  after apply: $(grep debug servers/server-b.conf)"
echo "  (the mutant was not repaired: it was re-cast from the mould)"
echo

echo "== 4. Delete a server entirely; the model resurrects it =="
rm servers/server-a.conf
"$TF" plan -input=false -no-color | grep -E '^Plan:' | sed 's/^/  plan says: /'
"$TF" apply -input=false -auto-approve >/dev/null
test -f servers/server-a.conf
echo "  server-a.conf is back, cast from the mould"
echo

echo "== 5. Cattle: raze everything, rebuild, new tag =="
before=$("$TF" output -raw herd_tag)
"$TF" destroy -input=false -auto-approve >/dev/null
test ! -f servers/server-a.conf
echo "  herd destroyed (no files left)"
"$TF" apply -input=false -auto-approve >/dev/null
after=$("$TF" output -raw herd_tag)
echo "  herd tag before: $before"
echo "  herd tag after:  $after"
test "$before" != "$after"
echo "  same configuration, new identity — cattle, not pets"
diff servers/server-a.conf servers/server-b.conf >/dev/null
echo "  and the two casts are again identical"
echo

echo "=== drift detected and converged, herd reborn from code — the snowflake is gone ==="
