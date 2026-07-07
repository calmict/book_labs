#!/usr/bin/env bash
set -euo pipefail

# Chapter 18 solution — refactoring without destroying, end to end:
#   0. the BEFORE: two managed containers (app, cache) + an orphan volume made
#      by hand (cap18-data);
#   1. the trap (18.1): renaming app -> frontend WITHOUT a moved block makes the
#      plan destroy the old and create the new (the address is the identity);
#   2. the refactor (the AFTER): moved renames in place, removed forgets the
#      cache without stopping it, import adopts the orphan volume — the whole
#      plan is "1 to import, 0 to add, 0 to change, 0 to destroy";
#   3. the proofs: frontend keeps app's ID, the cache is out of state yet still
#      running, the volume is imported and the next plan says No changes;
#   4. the manual scalpel (18.5): state list / show / mv.
#
# Needs a running Docker engine and free port 8110. Runs in a throwaway temp
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
  docker rm -f cap18-app cap18-cache >/dev/null 2>&1 || true
  docker volume rm cap18-data >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

cd "$WORK"

echo "== 0. The BEFORE: app + cache managed, plus an orphan volume =="
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
resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}
resource "docker_container" "app" {
  name  = "cap18-app"
  image = docker_image.web.image_id
  ports {
    internal = 80
    external = 8110
  }
}
resource "docker_container" "cache" {
  name  = "cap18-cache"
  image = docker_image.web.image_id
}
EOF
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
ID_APP=$(docker inspect -f '{{.Id}}' cap18-app)
docker volume create cap18-data >/dev/null
echo "  app ID (before) = ${ID_APP:0:12}  |  orphan volume cap18-data created by hand"
echo

echo "== 1. The trap: a naive rename destroys and recreates =="
# Same config as BEFORE, but the app resource is renamed to frontend with NO
# moved block — the address changed, so Terraform sees a different resource.
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
resource "docker_image" "web" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}
resource "docker_container" "frontend" {
  name  = "cap18-app"
  image = docker_image.web.image_id
  ports {
    internal = 80
    external = 8110
  }
}
resource "docker_container" "cache" {
  name  = "cap18-cache"
  image = docker_image.web.image_id
}
EOF
"$TF" plan -input=false -no-color >trap.out
grep -E 'docker_container.app will be destroyed' trap.out | sed 's/^ *# /  /'
grep -E 'docker_container.frontend will be created' trap.out | sed 's/^ *# /  /'
echo "  (the real container is identical — only the address changed — yet: demolish + rebuild)"
echo

echo "== 2. The refactor: moved + removed + import, zero destroy =="
cp "$DIR/main.tf" "$WORK/main.tf"
"$TF" plan -input=false -no-color >refactor.out
grep -E 'has moved to' refactor.out | sed 's/^ *# /  moved:   /'
grep -E 'will be removed from the OpenTofu state' refactor.out | sed 's/^ *# /  removed: /'
grep -E 'docker_volume.data will be imported' refactor.out | sed 's/^ *# /  import:  /'
grep -E '^Plan: 1 to import, 0 to add, 0 to change, 0 to destroy' refactor.out | sed 's/^/  /'
"$TF" apply -input=false -auto-approve >/dev/null
echo

echo "== 3. The proofs: nothing was demolished =="
ID_FRONT=$(docker inspect -f '{{.Id}}' cap18-app)
test "$ID_FRONT" = "$ID_APP"
echo "  moved:   frontend ID = ${ID_FRONT:0:12} == app ID (not recreated)"
test "$("$TF" state list | grep -c 'docker_container.cache')" -eq 0
echo "  removed: cache is out of the state, but container status = $(docker inspect -f '{{.State.Status}}' cap18-cache)"
test "$("$TF" state list | grep -c 'docker_volume.data')" -eq 1
"$TF" plan -input=false -no-color | grep -E 'No changes' | sed 's/^/  import:  /'
echo

echo "== 4. The manual scalpel: state list / show / mv =="
"$TF" state list | sed 's/^/  in the notebook: /'
"$TF" state show docker_container.frontend | grep -E '^\s+name ' | head -1 | sed 's/^ */  show: /'
"$TF" state mv docker_container.frontend docker_container.web_front 2>&1 | grep -iE 'moved' | sed 's/^/  mv: /'
"$TF" state mv docker_container.web_front docker_container.frontend >/dev/null
echo "  (mv done and undone — a cut no plan ever announced)"
echo

echo "=== the map was corrected four ways; not one building was demolished ==="
