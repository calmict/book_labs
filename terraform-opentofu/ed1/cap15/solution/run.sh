#!/usr/bin/env bash
set -euo pipefail

# Chapter 15 solution — count, for_each, conditionals and dynamic, end to end:
#   1. count multiplies by NUMBER: web[0], web[1], web[2] — and the trap:
#      remove the middle element from the list and the plan replaces one and
#      destroys another (the fragile index churns the tail);
#   2. for_each multiplies by NAME: web["alpha"]... — remove the middle one
#      now and only that one is destroyed (0 add, 0 change, 1 destroy);
#   3. the conditional: the canary exists only when enabled (count = 1 : 0);
#   4. the dynamic block: one labels block per map entry, landed on the
#      container (team, tier).
#
# Needs a running Docker engine (no host ports). Runs in a throwaway temp
# dir; guaranteed cleanup (destroy + rm) on exit.

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
  docker rm -f cap15-alpha cap15-bravo cap15-charlie cap15-canary >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

cd "$WORK"

echo "== 1. count: by NUMBER, and the fragile-index trap =="
cat >main.tf <<'EOF'
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}
provider "docker" {}
variable "fleet" {
  type    = list(string)
  default = ["alpha", "bravo", "charlie"]
}
resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}
resource "docker_container" "web" {
  count = length(var.fleet)
  name  = "cap15-${var.fleet[count.index]}"
  image = docker_image.web.image_id
}
EOF
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
"$TF" state list | grep -E 'docker_container.web\[' | sed 's/^/  address: /'
# Remove the MIDDLE element (bravo). count ties identity to position, so:
"$TF" plan -input=false -no-color -var 'fleet=["alpha","charlie"]' >trap.out
grep -E 'web\[1\] must be replaced' trap.out | sed 's/^ *# /  the trap: /'
grep -E 'web\[2\] will be destroyed' trap.out | sed 's/^ *# /  the trap: /'
echo "  (one removal in the middle, two resources upended — only alpha survives)"
"$TF" destroy -input=false -auto-approve >/dev/null
echo

echo "== 2. for_each: by NAME, the trap is cured =="
cp "$DIR/main.tf" "$WORK/main.tf"
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
"$TF" state list | grep -E 'docker_container.web\[' | sed 's/^/  address: /'
"$TF" plan -input=false -no-color -var 'fleet=["alpha","charlie"]' >cure.out
grep -E 'web\["bravo"\] will be destroyed' cure.out | sed 's/^ *# /  removed: /'
grep -E '^Plan: 0 to add, 0 to change, 1 to destroy' cure.out | sed 's/^/  /'
echo "  (alpha and charlie do not move: identity is the name, not the position)"
echo

echo "== 3. the conditional: the canary exists only when enabled =="
"$TF" plan -input=false -no-color -var canary_enabled=true >canary.out
grep -E 'docker_container.canary\[0\] will be created' canary.out | sed 's/^ *# /  enabled: /'
grep -E '^Plan: 1 to add' canary.out | sed 's/^/  /'
echo "  (count = var.canary_enabled ? 1 : 0 — 0 copies means declared, not created)"
echo

echo "== 4. the dynamic block: labels generated from the map =="
docker inspect -f '{{json .Config.Labels}}' cap15-alpha | tr ',' '\n' | grep -oE '"(team|tier)":"[a-z]+"' | sed 's/^/  label: /'
echo "  (one labels block per var.labels entry — no copy-paste)"
echo

echo "=== count by number (fragile), for_each by name (stable); conditionals gate, dynamic multiplies blocks ==="
