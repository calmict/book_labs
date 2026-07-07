#!/usr/bin/env bash
set -euo pipefail

# Chapter 22 solution — from commit to production, end to end:
#   0. the pipeline: check the workflow has the gate's four checks, the
#      delivery's push-to-main guard, and the OIDC permission;
#   1. the gate (CI): fmt -> init -> validate -> plan, exactly what the plan job
#      runs on every pull request;
#   2. the delivery (CD): apply the reviewed plan, as the deploy job does on
#      merge; the service answers on 8140;
#   3. GitOps: delete the container by hand (drift), and the belt's next pass
#      plans "1 to add" and pulls reality back to git.
#
# Needs a running Docker engine and free port 8140. Runs in a throwaway temp
# dir; guaranteed cleanup (destroy + rm) on exit.

if command -v tofu >/dev/null 2>&1; then
  TF=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF=terraform
else
  echo "ERROR: neither tofu nor terraform found (see SETUP.md)" >&2
  exit 1
fi
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found" >&2; exit 1; }

DIR=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() {
  (cd "$WORK" 2>/dev/null && "$TF" destroy -input=false -auto-approve >/dev/null 2>&1) || true
  docker rm -f cap22-app >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "== 0. The pipeline: is the belt wired correctly? =="
PIPE="$DIR/pipeline.yml.example"
grep -q 'tofu plan' "$PIPE"                                    && echo "  gate: the plan step is on the belt (TODO 1)"
grep -q "if: github.ref == 'refs/heads/main'" "$PIPE"         && echo "  delivery: apply is guarded to push-to-main (TODO 2)"
grep -q 'id-token: write' "$PIPE"                              && echo "  OIDC: id-token permission present (no static keys)"
echo

cp "$DIR/main.tf" "$WORK/"
cd "$WORK"

echo "== 1. The gate (CI): the same checks the plan job runs =="
"$TF" fmt -check -recursive >/dev/null && echo "  fmt -check: PASS"
"$TF" init -input=false >/dev/null && echo "  init: PASS"
"$TF" validate >/dev/null && echo "  validate: PASS"
"$TF" plan -input=false -no-color -out tfplan >/dev/null && echo "  plan: saved (the gate opens)"
echo

echo "== 2. The delivery (CD): apply the reviewed plan =="
"$TF" apply -input=false -no-color tfplan >/dev/null && echo "  apply: delivered"
ok=""
for _ in $(seq 1 15); do
  if curl -sf http://localhost:8140 2>/dev/null | grep -q 'Welcome to nginx'; then ok=1; break; fi
  sleep 1
done
test -n "$ok"
echo "  the service answers on 8140 (Welcome to nginx)"
echo

echo "== 3. GitOps: git is the source of truth (drift correction) =="
docker rm -f cap22-app >/dev/null
echo "  someone deleted the container BY HAND — reality drifted from git"
"$TF" plan -input=false -no-color | grep -E '^Plan:' | sed 's/^/  next pass plans: /'
"$TF" apply -input=false -auto-approve >/dev/null
ok=""
for _ in $(seq 1 15); do
  if curl -sf http://localhost:8140 2>/dev/null | grep -q 'Welcome to nginx'; then ok=1; break; fi
  sleep 1
done
test -n "$ok"
echo "  reconciled: the service answers again — the repo won, not the hand edit"
echo

echo "=== a commit in, running infrastructure out; the belt runs the pyramid and keeps reality equal to git ==="
