#!/usr/bin/env bash
set -euo pipefail

# Chapter 6 solution — the first stone, end to end:
#   0. the two binaries: version of the one YOU installed;
#   1. init under the lens: the provider binary weighed, the lock file born,
#      the second init instant;
#   2. the saved plan: plan -out, then apply of the file with NO prompt;
#   3. the first stone: curl answers from code-built nginx;
#   4. the everyday commands: state list, output, show;
#   5. the port change: a replace, not an update (chapter 3's echo);
#   6. the demolition: state empty, but .terraform and the lock survive.
#
# Needs a running Docker engine and free ports 8087/8088. Runs in a
# throwaway temp dir; guaranteed cleanup (destroy + rm) on exit.

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
  (cd "$WORK" 2>/dev/null && "$TF" destroy -input=false -auto-approve >/dev/null 2>&1) || true
  rm -rf "$WORK"
}
trap cleanup EXIT

cp "$DIR/main.tf" "$WORK/"
cd "$WORK"

echo "== 0. The binary YOU installed =="
"$TF" version | head -1 | sed 's/^/  /'
echo

echo "== 1. init, under the lens =="
"$TF" init -input=false >/dev/null
test -f .terraform.lock.hcl
echo "  .terraform.lock.hcl: born (chapter 7's protagonist)"
bin=$(find .terraform -name 'terraform-provider-*' | head -1)
size_mb=$(du -m "$bin" | cut -f1)
echo "  provider binary: ${size_mb} MB — THIS is the translators' installation"
test "$size_mb" -gt 10
t0=$(date +%s)
"$TF" init -input=false >/dev/null
t1=$(date +%s)
echo "  second init: $((t1 - t0))s (idempotent, like everything around here)"
echo

echo "== 2. The saved plan: a contract, no questions asked =="
"$TF" plan -input=false -no-color -out=first.plan | grep -E '^(Plan:|Saved the plan)' | sed 's/^/  /'
# note: NO -auto-approve below — the saved plan itself is the approval.
"$TF" apply -input=false first.plan >/dev/null
echo "  apply first.plan ran with no prompt: it executes EXACTLY what was planned"
echo

echo "== 3. The first stone, answering =="
ok=""
for _ in $(seq 1 10); do
  if curl -sS --max-time 5 http://localhost:8087 2>/dev/null | grep -q 'Welcome to nginx'; then
    ok=1
    break
  fi
  sleep 2
done
test -n "$ok"
echo "  http://localhost:8087 -> Welcome to nginx! (switched on from code)"
echo

echo "== 4. The three everyday questions =="
echo "  state list (what am I managing?):"
"$TF" state list | sed 's/^/    /'
test "$("$TF" state list | wc -l)" -eq 2
echo "  output -raw url (what did I promise?): $("$TF" output -raw url)"
echo "  show (what does it look like?): $("$TF" show -no-color | grep -c ' = ') attributes tracked, most never written by hand"
echo

echo "== 5. The port change: chapter 3 knocking =="
sed -i 's/external = 8087/external = 8088/' main.tf
"$TF" plan -input=false -no-color > plan.out
grep -E 'must be replaced' plan.out | sed 's/^ *//;s/^/  plan says: /'
grep -E 'forces replacement' plan.out | head -1 | sed 's/^ *//;s/^/  marker:    /'
"$TF" apply -input=false -auto-approve >/dev/null
curl -sS --max-time 5 http://localhost:8088 | grep -q 'Welcome to nginx'
echo "  http://localhost:8088 answers: replaced, not updated"
echo

echo "== 6. The demolition, and what remains =="
"$TF" destroy -input=false -auto-approve >/dev/null
test -z "$("$TF" state list)"
echo "  state list: empty (the infrastructure is gone)"
test -d .terraform
test -f .terraform.lock.hcl
echo "  but .terraform/ and the lock file survive: destroy demolishes the"
echo "  infrastructure, not the architect's studio"
test -z "$(docker ps -aq --filter name=cap06-web)"
echo "  no cap06 container left"
echo

echo "=== one config, one cycle, one real service: the first stone is yours ==="
