#!/usr/bin/env bash
set -euo pipefail

# Chapter 13 solution — the fire doors, end to end:
#   0. the monolith: one rename in the network team's turf, and the plan
#      burns the app's container too (blast radius = the whole notebook);
#   1. the cut: two rooms, two notebooks on the same Consul noticeboard;
#   2. the intercom: the app reads the network's OUTPUTS via
#      terraform_remote_state (resolved at plan time);
#   3. proof 1: plan -destroy in the app room sees only the app;
#      proof 2: the network's plan passes WHILE the app's apply holds its
#      own lock — two queues, two locks.
#
# Needs a running Docker engine and free port 8500. Runs in a throwaway
# temp dir; guaranteed cleanup (both destroys + consul + rm) on exit.

DIR=$(cd "$(dirname "$0")" && pwd)
CONSUL=cap13-consul

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
  (cd "$WORK/app" 2>/dev/null && "$TF" destroy -input=false -auto-approve >/dev/null 2>&1) || true
  (cd "$WORK/network" 2>/dev/null && "$TF" destroy -input=false -auto-approve >/dev/null 2>&1) || true
  (cd "$WORK/monolith" 2>/dev/null && "$TF" destroy -input=false -auto-approve >/dev/null 2>&1) || true
  docker rm -f "$CONSUL" cap13-app >/dev/null 2>&1 || true
  docker network rm cap13-core-net >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "== 0. The monolith, and its radius =="
docker rm -f "$CONSUL" >/dev/null 2>&1 || true
docker run -d --name "$CONSUL" -p 127.0.0.1:8500:8500 \
  hashicorp/consul:1.20 agent -dev -client=0.0.0.0 >/dev/null
ready=""
for _ in $(seq 1 20); do
  if curl -sf http://127.0.0.1:8500/v1/status/leader >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
test -n "$ready"
mkdir -p "$WORK/monolith"
cat > "$WORK/monolith/main.tf" <<'EOF'
terraform {
  backend "consul" {
    address = "127.0.0.1:8500"
    scheme  = "http"
    path    = "book-labs/cap13/monolith"
  }
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_network" "core" {
  name = "cap13-core-net"
}

resource "docker_image" "app" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "app" {
  name  = "cap13-app"
  image = docker_image.app.image_id

  networks_advanced {
    name = docker_network.core.name
  }
}
EOF
cd "$WORK/monolith"
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
echo "  monolith applied (one notebook for two teams)"
sed -i 's/cap13-core-net/cap13-core-net-v2/' main.tf
"$TF" plan -input=false -no-color > fire.out
grep -E 'must be replaced' fire.out | sed 's/^ *# /  the fire: /'
test "$(grep -c 'must be replaced' fire.out)" -eq 2
echo "  (the network team touched ITS resource; the app burns too)"
sed -i 's/cap13-core-net-v2/cap13-core-net/' main.tf
"$TF" destroy -input=false -auto-approve >/dev/null
echo "  monolith demolished (chapter 18 will cut WITHOUT demolishing)"
echo

echo "== 1. The cut: two rooms, two notebooks =="
mkdir -p "$WORK/network" "$WORK/app"
cp "$DIR/network/main.tf" "$WORK/network/"
cp "$DIR/app/main.tf" "$WORK/app/"
cd "$WORK/network"
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
echo "  network room applied; its official door: network_name = $("$TF" output -raw network_name)"
echo

echo "== 2. The intercom: reading the other notebook's outputs =="
cd "$WORK/app"
"$TF" init -input=false >/dev/null
"$TF" plan -input=false -no-color > plan.out
grep -E 'terraform_remote_state.network: Read complete' plan.out | sed 's/^/  /'
grep -E '"cap13-core-net"' plan.out >/dev/null
echo "  the network name is already resolved in the plan (chapter 10 at work)"
"$TF" apply -input=false -auto-approve >/dev/null
docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' cap13-app | sed 's/^/  cap13-app joined: /'
echo

echo "== 3. Proof 1: the worst command, in the right room =="
"$TF" plan -destroy -input=false -no-color > boom.out
grep -E 'will be destroyed' boom.out | sed 's/^ *# /  in the radius: /'
grep -E 'docker_network' boom.out >/dev/null && { echo "unexpected: network in radius"; exit 1; }
echo "  the network does NOT appear: it is not in this notebook"
echo

echo "== 3. Proof 2: two queues, two locks =="
"$TF" destroy -input=false -auto-approve >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null 2>&1 &
apid=$!
sleep 4
cd "$WORK/network"
"$TF" plan -input=false -no-color | grep -E 'No changes' | sed 's/^/  network plan, DURING the app apply: /'
echo "  (in chapter 12 this would have hit the lock; now each room has its own)"
wait "$apid"
echo

echo "== Cleanup: consumers before providers =="
cd "$WORK/app"
"$TF" destroy -input=false -auto-approve >/dev/null
cd "$WORK/network"
"$TF" destroy -input=false -auto-approve >/dev/null
docker rm -f "$CONSUL" >/dev/null
echo "  app down, network down, noticeboard removed"
echo

echo "=== one notebook burns whole; fire doors give each team a room, a queue, and a contract ==="
