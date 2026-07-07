#!/usr/bin/env bash
set -euo pipefail

# Chapter 14 solution — the three doors, end to end:
#   1. the closed door: environment has no default, so a plan with no input
#      is refused (a required variable);
#   2. the bouncer: validation rejects environment=banana before the graph;
#   3. the three entrances: -var, TF_VAR_ and terraform.tfvars all set it,
#      and when they disagree the CLI wins (precedence: -var > tfvars > env);
#   4. the kitchen and the service door: a local derives the name, an output
#      publishes the URL, and the page answers on the chosen port;
#   5. chapter 3's echo: change the environment and the container is replaced.
#
# Needs a running Docker engine and free port 8095. Runs in a throwaway
# temp dir; guaranteed cleanup (destroy + rm) on exit.

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
  (cd "$WORK" 2>/dev/null && "$TF" destroy -input=false -auto-approve -var environment=dev >/dev/null 2>&1) || true
  docker rm -f cap14-web-dev cap14-web-prod >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

cp "$DIR/main.tf" "$WORK/"
cd "$WORK"
"$TF" init -input=false >/dev/null

echo "== 1. The closed door: a required variable =="
if "$TF" plan -input=false -no-color >req.out 2>&1; then
  echo "unexpected: the plan succeeded with no environment" >&2; exit 1
fi
grep -q 'No value for required variable' req.out
echo "  tofu refuses: No value for required variable"
echo "  (no default means whoever uses this config must choose)"
echo

echo "== 2. The bouncer: validation before the graph =="
if "$TF" plan -input=false -no-color -var environment=banana >val.out 2>&1; then
  echo "unexpected: banana passed the bouncer" >&2; exit 1
fi
grep -q 'Invalid value for variable' val.out
grep -q 'must be one of' val.out
echo "  tofu bounces banana: Invalid value for variable (our message fired)"
echo

echo "== 3. The three entrances, and who wins =="
"$TF" plan -input=false -no-color -var environment=dev >/dev/null
echo "  -var environment=dev: accepted"
TF_VAR_environment=staging "$TF" plan -input=false -no-color >/dev/null
echo "  TF_VAR_environment=staging: accepted"
printf 'environment = "dev"\n' >terraform.tfvars
"$TF" plan -input=false -no-color >/dev/null
echo "  terraform.tfvars (environment=dev): accepted"
# tfvars says dev, the CLI says prod — the built name proves who won.
"$TF" plan -input=false -no-color -var environment=prod >prec.out
grep -q 'cap14-web-prod' prec.out
echo "  precedence: tfvars=dev + -var=prod -> plan builds cap14-web-prod (CLI wins)"
rm -f terraform.tfvars
echo

echo "== 4. The kitchen and the service door =="
"$TF" apply -input=false -auto-approve -var environment=dev >/dev/null
echo "  output url = $("$TF" output -raw url)"
ok=""
for _ in $(seq 1 15); do
  if curl -sf http://localhost:8095 2>/dev/null | grep -q 'Welcome to nginx'; then ok=1; break; fi
  sleep 1
done
test -n "$ok"
echo "  the page answers on 8095 (Welcome to nginx)"
echo

echo "== 5. Chapter 3's echo: the environment forces a replace =="
"$TF" plan -input=false -no-color -var environment=prod >repl.out
grep -E 'must be replaced' repl.out | head -1 | sed 's/^ *# /  /'
grep -E 'forces replacement' repl.out | head -1 | sed 's/^ *//;s/^/  /'
echo "  (a value in one door moved through the local and changed the name)"
echo

echo "=== three doors: input in, results out, the kitchen in between — and the graph still moves ==="
