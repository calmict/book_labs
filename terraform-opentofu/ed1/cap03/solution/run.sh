#!/usr/bin/env bash
set -euo pipefail

# Chapter 3 solution — renovate or rebuild, end to end:
#   0. build the container (nginx 1.25, memory 128);
#   1. renovation: memory 128 -> 256 is an in-place update (same container ID);
#   2. reconstruction: version 1.25 -> 1.26 forces a replacement
#      (destroy and then create, "# forces replacement" markers);
#   3. create_before_destroy flips the order (version 1.26 -> 1.27);
#   4. prevent_destroy blocks the destroy AND the next version bump.
#
# Needs a running Docker engine. Downloads three small nginx alpine images
# (kept locally on cleanup: keep_locally = true). Runs in a throwaway temp
# dir; guaranteed cleanup (catch off + destroy + rm) on exit.

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
  (
    cd "$WORK" 2>/dev/null || exit 0
    sed -i '/prevent_destroy/d' main.tf 2>/dev/null || true
    "$TF" destroy -input=false -auto-approve >/dev/null 2>&1 || true
  )
  rm -rf "$WORK"
}
trap cleanup EXIT

cd "$WORK"
# The exercise's starting model (the completed TODOs arrive in phases 3-4).
cat > main.tf <<'EOF'
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

locals {
  nginx_version = "1.25-alpine"
}

resource "docker_image" "web" {
  name         = "nginx:${local.nginx_version}"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = "cap03-web-${replace(local.nginx_version, ".", "-")}"
  image = docker_image.web.image_id

  memory = 128
}
EOF

echo "== 0. The first building (nginx 1.25, memory 128) =="
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
docker exec cap03-web-1-25-alpine nginx -v 2>&1 | sed 's/^/  /'
echo

echo "== 1. Renovation: memory 128 -> 256, in-place =="
id_before=$(docker inspect -f '{{.Id}}' cap03-web-1-25-alpine)
sed -i 's/memory = 128/memory = 256/' main.tf
"$TF" plan -input=false -no-color | grep -E 'will be updated in-place' | sed 's/^ *//;s/^/  plan says: /'
"$TF" apply -input=false -auto-approve >/dev/null
id_after=$(docker inspect -f '{{.Id}}' cap03-web-1-25-alpine)
test "$id_before" = "$id_after"
echo "  same container ID before and after: renovated, never demolished"
echo "  memory now: $(docker inspect -f '{{.HostConfig.Memory}}' cap03-web-1-25-alpine) bytes"
echo

echo "== 2. Reconstruction: version 1.25 -> 1.26, replace =="
sed -i 's/1.25-alpine/1.26-alpine/' main.tf
"$TF" plan -input=false -no-color > plan.out
grep -E 'must be replaced' plan.out | sed 's/^ *//;s/^/  plan says: /'
grep -cE 'forces replacement' plan.out | sed 's/^/  attributes marked "# forces replacement": /'
grep -E 'destroy and then create replacement' plan.out | head -1 | sed 's/^ *//;s/^/  announced order: /'
"$TF" apply -input=false -auto-approve >/dev/null
docker exec cap03-web-1-26-alpine nginx -v 2>&1 | sed 's/^/  /'
test -z "$(docker ps -aq --filter name=cap03-web-1-25-alpine)"
echo "  old container gone: nobody upgraded nginx inside — the building was replaced"
echo

echo "== 3. create_before_destroy: the order flips (version 1.26 -> 1.27) =="
sed -i 's/  memory = 256/  memory = 256\n\n  lifecycle {\n    create_before_destroy = true\n  }/' main.tf
sed -i 's/1.26-alpine/1.27-alpine/' main.tf
"$TF" plan -input=false -no-color | grep -E 'create replacement and then destroy' | head -1 | sed 's/^ *//;s/^/  announced order now: /'
"$TF" apply -input=false -auto-approve >/dev/null
docker exec cap03-web-1-27-alpine nginx -v 2>&1 | sed 's/^/  /'
echo "  (possible because the name contains the version: identities never contend)"
echo

echo "== 4. prevent_destroy: the safety catch =="
sed -i 's/    create_before_destroy = true/    create_before_destroy = true\n    prevent_destroy       = true/' main.tf
rc=0
"$TF" destroy -input=false -auto-approve -no-color >destroy.out 2>&1 || rc=$?
test "$rc" -ne 0
grep -E 'Instance cannot be destroyed' destroy.out | head -1 | sed 's/^/  destroy blocked: /'
sed -i 's/1.27-alpine/1.28-alpine/' main.tf
rc=0
"$TF" plan -input=false -no-color >bump.out 2>&1 || rc=$?
test "$rc" -ne 0
grep -E 'Instance cannot be destroyed' bump.out | head -1 | sed 's/^/  version bump blocked too: /'
echo "  (a replace IS a destroy plus a create: the catch blocks both)"
sed -i 's/1.28-alpine/1.27-alpine/' main.tf
echo

echo "== Cleanup: catch off (in code, deliberately), then destroy =="
sed -i '/prevent_destroy/d' main.tf
"$TF" destroy -input=false -auto-approve >/dev/null
test -z "$(docker ps -aq --filter name=cap03-web)"
echo "  no cap03 container left"
echo

echo "=== two roads, both announced in the plan: renovation passes through the object, reconstruction replaces it ==="
