#!/usr/bin/env bash
set -euo pipefail

# Chapter 21 solution — the validation pyramid, end to end:
#   0. the base: fmt (form) and validate (internal consistency) — instant;
#   1. the middle: policy as code — read policy.rego.example (no scanner here);
#   2. the top: tofu test — behaviour tests (plan asserts, an expect_failures
#      case, and an apply case that checks the real container);
#   3. why tests exist: break the config and watch a test REJECT the regression.
#
# Needs a running Docker engine and free port 8130. Runs in a throwaway temp
# dir; guaranteed cleanup (rm of containers + dir) on exit.

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
  docker rm -f cap21-dev cap21-broken >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

strip() { sed -E 's/\x1b\[[0-9;]*m//g'; }

cp "$DIR/main.tf" "$DIR/tests.tftest.hcl" "$WORK/"
cd "$WORK"
"$TF" init -input=false >/dev/null

echo "== 0. The base: fmt and validate (instant) =="
"$TF" fmt -check -recursive >/dev/null && echo "  fmt -check: clean (the form is fine)"
"$TF" validate >/dev/null && echo "  validate:   the configuration is internally consistent"
echo

echo "== 1. The middle: policy as code (gallery) =="
echo "  policy.rego.example denies unpinned images; this config pins nginx:1.27-alpine -> would pass"
echo

echo "== 2. The top: tofu test (behaviour) =="
"$TF" test 2>&1 | strip | grep -E 'run "|passed, ' | sed 's/^/  /'
echo

echo "== 3. Why tests exist: break the config, the test rejects it =="
# Introduce a regression: the name no longer derives from the environment.
# shellcheck disable=SC2016  # the ${...} is literal HCL, not a shell expansion
sed -i 's/container_name = "cap21-${var.environment}"/container_name = "cap21-broken"/' main.tf
"$TF" test >broken.out 2>&1 || true
grep -E 'Test assertion failed|is "cap21-broken"|[0-9]+ failed\.' broken.out |
  strip | sed -E 's/^[[:space:]]*│?[[:space:]]*//;s/^│?[[:space:]]*//' | sed 's/^/  /' | head -3
echo "  (the behaviour test caught a change the base checks could not: fmt and validate still pass on it)"
"$TF" fmt -check >/dev/null && "$TF" validate >/dev/null && echo "  proof: fmt + validate are green on the BROKEN config — only the test saw the bug"
echo

echo "=== base catches typos, policy catches risks, tests catch broken behaviour ==="
