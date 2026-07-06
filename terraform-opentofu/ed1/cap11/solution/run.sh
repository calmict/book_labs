#!/usr/bin/env bash
set -euo pipefail

# Chapter 11 solution — the notebook and its secrets, end to end:
#   0. a small world with a secret: output redacted (<sensitive>);
#   1. inside the notebook: serial, lineage, the code->reality binding,
#      and the graph's edges (dependencies) recorded;
#   2. the secret IN PLAIN TEXT in the very same file;
#   3. the three sources: a container deleted behind the model's back,
#      -refresh-only syncs the memory alone, then plan rebuilds;
#   4. the colleague: same code, empty notebook -> full-rebuild plan,
#      apply crashes on the shared reality, half-written state.
#
# Needs a running Docker engine. Runs in a throwaway temp dir; guaranteed
# cleanup (both destroys + rm) on exit.

DIR=$(cd "$(dirname "$0")" && pwd)

if command -v tofu >/dev/null 2>&1; then
  TF=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF=terraform
else
  echo "ERROR: neither tofu nor terraform found (see SETUP.md)" >&2
  exit 1
fi
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found" >&2; exit 1; }

WORK=$(mktemp -d)
cleanup() {
  (cd "$WORK/colleague" 2>/dev/null && "$TF" destroy -input=false -auto-approve >/dev/null 2>&1) || true
  (cd "$WORK/mine" 2>/dev/null && "$TF" destroy -input=false -auto-approve >/dev/null 2>&1) || true
  docker rm -f cap11-web >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p "$WORK/mine"
cp "$DIR/main.tf" "$WORK/mine/"
cd "$WORK/mine"

echo "== 0. A small world with a secret =="
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
"$TF" output -no-color | grep -F '<sensitive>' | sed 's/^/  output says: /'
echo

echo "== 1. Inside the notebook =="
grep -o '"serial":[0-9]*' terraform.tfstate | sed 's/^/  /'
grep -o '"lineage":"[^"]*"' terraform.tfstate | sed 's/^/  /'
cid=$(grep -o '"name":"cap11-web"' terraform.tfstate)
test -n "$cid"
echo "  the binding is there: docker_container.web <-> the real container"
grep -o '"dependencies":\["docker_image.web"\]' terraform.tfstate | sed 's/^/  even the graph: /'
echo

echo "== 2. The secret, in plain text in the very same file =="
secret=$(grep -o '"result":"[^"]*"' terraform.tfstate | head -1)
test -n "$secret"
echo "  found in the state: \"result\":\"******\" (redacted here — but NOT in the file)"
grep -o '"value":"[^"]*"' terraform.tfstate >/dev/null
echo "  (the sensitive OUTPUT value is in the state too: whoever reads the"
echo "   state reads every secret — never commit it, restrict it, encrypt it)"
echo

echo "== 3. The three sources of truth =="
docker rm -f cap11-web >/dev/null
"$TF" plan -refresh-only -input=false -no-color > refresh.out
grep -E 'changed outside' refresh.out | head -1 | sed 's/^/  /'
grep -E 'has been deleted' refresh.out | head -1 | sed 's/^ */  /'
"$TF" apply -refresh-only -input=false -auto-approve >/dev/null
test -z "$("$TF" state list | grep docker_container)"
echo "  after apply -refresh-only: the memory forgot the ghost (reality untouched)"
"$TF" plan -input=false -no-color | grep -E '^Plan:' | sed 's/^/  now code vs memory: /'
"$TF" apply -input=false -auto-approve >/dev/null
echo "  applied: the world is whole again"
echo

echo "== 4. The colleague with the empty notebook =="
mkdir -p "$WORK/colleague"
cp main.tf "$WORK/colleague/"
cd "$WORK/colleague"
"$TF" init -input=false >/dev/null
"$TF" plan -input=false -no-color | grep -E '^Plan:' | sed 's/^/  his plan: /'
rc=0
"$TF" apply -input=false -auto-approve -no-color >apply.out 2>&1 || rc=$?
test "$rc" -ne 0
grep -E 'already in use' apply.out | head -1 | sed 's/^ */  his apply: ... /'
echo "  his notebook after the crash (half written):"
"$TF" state list | sed 's/^/    /'
test -z "$("$TF" state list | grep docker_container)"
test "$("$TF" state list | wc -l)" -eq 2
echo "  (same code, two memories, one reality: separate state does not scale)"
echo

echo "== Cleanup: two notebooks, two destroys =="
"$TF" destroy -input=false -auto-approve >/dev/null
cd "$WORK/mine"
"$TF" destroy -input=false -auto-approve >/dev/null
test -z "$(docker ps -aq --filter name=cap11-web)"
echo "  both destroyed, no cap11 container left"
echo

echo "=== the notebook binds code to reality, keeps every secret, and must be one — shared and locked ==="
