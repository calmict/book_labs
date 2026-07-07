#!/usr/bin/env bash
set -euo pipefail

# Chapter 19 solution — managing multiple environments, end to end:
#   PART A, the drawer (workspaces): one codebase, one backend, one state per
#     workspace. terraform.workspace drives dev and prod; the two states live
#     side by side in terraform.tfstate.d/ — DRY, but no wall.
#   PART B, the room (separate directories): a shared module called from dev/
#     and prod/, each its own directory, its own state, its own init. Destroying
#     dev leaves prod untouched, and prod's plan cannot even see dev — real
#     walls, chapter 13's radii applied to environments.
#
# Needs a running Docker engine and free ports 8120-8123. Runs in a throwaway
# temp dir; guaranteed cleanup (rm of containers + dir) on exit.

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
  docker rm -f cap19-dev cap19-prod cap19dir-dev cap19dir-prod >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "== PART A: the drawer (workspaces) =="
cp -r "$DIR/workspaces" "$WORK/ws"
cd "$WORK/ws"
"$TF" init -input=false >/dev/null
"$TF" workspace new dev >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
echo "  dev  drawer: $("$TF" output -raw who)"
"$TF" workspace new prod >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
echo "  prod drawer: $("$TF" output -raw who)"
echo "  workspace list:"
"$TF" workspace list | sed 's/^/    /'
# One codebase, two states side by side in the same backend:
test -f terraform.tfstate.d/dev/terraform.tfstate
test -f terraform.tfstate.d/prod/terraform.tfstate
echo "  two states, one backend: terraform.tfstate.d/{dev,prod}/terraform.tfstate"
docker ps --filter 'name=cap19-' --format '{{.Names}} -> {{.Ports}}' | sort | sed 's/^/    /'
echo

echo "== PART B: the room (separate directories) =="
cp -r "$DIR/directories" "$WORK/dir"
cd "$WORK/dir/dev"
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
echo "  dev  room: $("$TF" output -raw url)"
cd "$WORK/dir/prod"
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
echo "  prod room: $("$TF" output -raw url)"
# Each directory has its own state:
test -f "$WORK/dir/dev/terraform.tfstate"
test -f "$WORK/dir/prod/terraform.tfstate"
echo "  separate states: dir/dev/terraform.tfstate and dir/prod/terraform.tfstate"
docker ps --filter 'name=cap19dir-' --format '{{.Names}} -> {{.Ports}}' | sort | sed 's/^/    /'
echo

echo "== PART B proof: destroy dev, prod is untouched =="
cd "$WORK/dir/dev"
"$TF" destroy -input=false -auto-approve >/dev/null
echo "  after destroy dev, still running: $(docker ps --filter 'name=cap19dir-' --format '{{.Names}}' | sort | tr '\n' ' ')"
cd "$WORK/dir/prod"
"$TF" plan -input=false -no-color | grep -E 'No changes' | sed 's/^/  prod plan: /'
echo "  (from the prod room you cannot even see dev — real walls)"
echo

echo "=== drawers share one cabinet (DRY, no wall); rooms have real walls (isolation) ==="
