#!/usr/bin/env bash
set -euo pipefail

# Chapter 5 solution — the skyscraper's datasheet, end to end:
#   1. apply the completed card, then read the outputs: the duplicate
#      "steel" survives in the list, disappears (and gets sorted) in the
#      set; map, object and tuple render distinctly;
#   2. the datasheet file carries every access syntax, interpolated;
#   3. idempotence check (No changes);
#   4. tofu fmt on a nightmare-layout file: -diff -check flags it, fmt
#      fixes the FORM, -check then passes — the meaning never changed.
#
# Runs in a throwaway temp dir; guaranteed cleanup (destroy + rm) on exit.

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

echo "== 1. Apply the card, read the outputs =="
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
list_steel=$("$TF" output -no-color materials | grep -c '"steel"')
set_steel=$("$TF" output -no-color unique_materials | grep -c '"steel"')
echo "  \"steel\" in the list: ${list_steel} times (order kept, duplicates kept)"
echo "  \"steel\" in the set:  ${set_steel} time  (duplicate gone)"
test "$list_steel" -eq 2
test "$set_steel" -eq 1
"$TF" output -no-color unique_materials | head -1 | grep -q 'toset' \
  && echo "  the output even labels it: toset([...]) — alphabetical, unordered by nature"
first_item=$("$TF" output -no-color unique_materials | sed -n '2p')
case "$first_item" in *concrete*) echo "  first element: concrete (sorted, not insertion order)" ;; *) echo "unexpected order: $first_item"; exit 1 ;; esac
echo

echo "== 2. The datasheet: every access syntax, interpolated =="
grep -E '== Torre Aurora ==' datasheet.txt >/dev/null
grep -E '^street     : Via dei Grafi 4$' datasheet.txt >/dev/null
grep -E '^ground area: 650 sqm$' datasheet.txt >/dev/null
grep -E '^latitude   : 45.4642$' datasheet.txt >/dev/null
grep -E '^materials  : concrete, glass, steel$' datasheet.txt >/dev/null
sed 's/^/  /' datasheet.txt
echo

echo "== 3. Idempotence =="
"$TF" apply -input=false -auto-approve -no-color | grep -E 'No changes' | sed 's/^/  /'
echo

echo "== 4. The sloppy colleague: fmt fixes the form, never the meaning =="
mkdir fmtlab && cd fmtlab
cat > messy.tf <<'EOF'
locals {
      lobby_name= "Atrio Nord"
  lobby_seats =        18
        lobby_open =true
   lobby_hours={ weekdays="8-20"
   weekend =  "9-13" }
}
EOF
rc=0
"$TF" fmt -check messy.tf >/dev/null 2>&1 || rc=$?
test "$rc" -ne 0
echo "  fmt -check flags the file (exit $rc), and -diff would show:"
cp messy.tf messy.bak
"$TF" fmt messy.tf >/dev/null
diff messy.bak messy.tf | grep -E '^[<>]' | sed 's/^/    /' || true
"$TF" fmt -check messy.tf >/dev/null
echo "  after fmt: -check is silent. Values, names and order: untouched."
grep -q 'lobby_seats = 18' messy.tf
grep -q '"Atrio Nord"' messy.tf
cd "$WORK"
echo

echo "=== every type in its place, and the card rendered from the model ==="
