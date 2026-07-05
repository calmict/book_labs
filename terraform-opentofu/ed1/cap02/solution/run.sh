#!/usr/bin/env bash
set -euo pipefail

# Chapter 2 solution — the recipe and the photograph, end to end:
#   0. the naive recipe works once, then crashes on the second run;
#   1. the guarded recipe (provision.sh) survives two runs;
#   2. but the guard is blind: a vandalised config walks past it;
#   3. the photograph (main.tf) converges from four different starts.
#
# Runs in a throwaway temp dir; guaranteed cleanup (destroy + rm) on exit.
# Works with tofu or terraform.

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

cp "$DIR/main.tf" "$DIR/provision.sh" "$WORK/"
cd "$WORK"

echo "== 0. The naive recipe: perfect once, dead twice =="
cat > naive.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir fleet
for i in 1 2 3; do
  printf 'hostname   = server-%s\npackages   = nginx, openssl\nport       = 8080\ndebug_mode = off\n' "$i" > "fleet/server-$i.conf"
done
for i in 1 2 3; do
  echo "server-$i registered" >> fleet/inventory.txt
done
EOF
chmod +x naive.sh
./naive.sh
echo "  first run: fleet built ($(find fleet -type f | wc -l) files)"
rc=0
./naive.sh 2>naive.err || rc=$?
test "$rc" -ne 0
echo "  second run: CRASHED (exit $rc) — $(head -1 naive.err)"
echo "  (the steps only make sense from ONE starting point: emptiness)"
rm -rf fleet naive.err
echo

echo "== 1. The guarded recipe: hand-made idempotence =="
./provision.sh >/dev/null
./provision.sh | grep -c 'skipping' | sed 's/^/  second run fine, steps skipped: /'
echo

echo "== 2. The blind guard: drift walks past it =="
sed -i 's/debug_mode = off/debug_mode = on/' fleet/server-2.conf
./provision.sh | grep '2.2' | sed 's/^/  /'
echo "  after the re-run: $(grep debug fleet/server-2.conf)"
echo "  (the guard checks EXISTENCE, not CONTENT: re-runnable is not convergent)"
rm -rf fleet
echo

echo "== 3. The photograph, start 1: empty yard =="
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve -no-color | grep -E '^Apply complete' | sed 's/^/  /'
echo

echo "== 3. The photograph, start 2: vandalised =="
sed -i 's/debug_mode = off/debug_mode = on/' fleet/server-2.conf
"$TF" plan -input=false -no-color | grep -E '^Plan:' | sed 's/^/  plan says: /'
"$TF" apply -input=false -auto-approve >/dev/null
echo "  after apply: $(grep debug fleet/server-2.conf)"
echo "  (the drift the guard skipped is seen, and absorbed)"
echo

echo "== 3. The photograph, start 3: half-built (where the naive recipe died) =="
rm fleet/server-3.conf
: > fleet/inventory.txt
"$TF" plan -input=false -no-color | grep -E '^Plan:' | sed 's/^/  plan says: /'
"$TF" apply -input=false -auto-approve >/dev/null
test -f fleet/server-3.conf
test "$(wc -l < fleet/inventory.txt)" -eq 3
echo "  server-3 is back, inventory lists $(wc -l < fleet/inventory.txt) servers again"
echo

echo "== 3. The photograph, start 4: already complete =="
"$TF" apply -input=false -auto-approve -no-color | grep -E 'No changes' | sed 's/^/  /'
echo

echo "=== one command, four starts, four different plans, one result: convergence ==="
