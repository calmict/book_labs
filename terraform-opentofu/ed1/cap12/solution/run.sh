#!/usr/bin/env bash
set -euo pipefail

# Chapter 12 solution — one notebook, with a lock, end to end:
#   0. the noticeboard (Consul in a container) and a world with LOCAL state;
#   1. the move: backend block + init -migrate-state — local file empties,
#      the state appears in Consul's KV;
#   2. the colleague, second act: he attaches (no migration) and his first
#      plan says No changes — he reads the SAME memory;
#   3. the lock: a slow apply on one side, the colleague's plan on the
#      other -> Error acquiring the state lock, with the full name tag;
#   4. one notebook, one destroy — then the noticeboard goes away.
#
# Needs a running Docker engine and free port 8500. Runs in a throwaway
# temp dir; guaranteed cleanup (destroy + consul removal + rm) on exit.

if command -v tofu >/dev/null 2>&1; then
  TF=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF=terraform
else
  echo "ERROR: neither tofu nor terraform found (see SETUP.md)" >&2
  exit 1
fi
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found" >&2; exit 1; }

CONSUL=cap12-consul
WORK=$(mktemp -d)
cleanup() {
  (cd "$WORK/mine" 2>/dev/null && "$TF" destroy -input=false -auto-approve >/dev/null 2>&1) || true
  docker rm -f "$CONSUL" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p "$WORK/mine"
cd "$WORK/mine"

echo "== 0. The noticeboard, and a world with local state =="
docker rm -f "$CONSUL" >/dev/null 2>&1 || true
docker run -d --name "$CONSUL" -p 127.0.0.1:8500:8500 \
  hashicorp/consul:1.20 agent -dev -client=0.0.0.0 >/dev/null
ready=""
for _ in $(seq 1 20); do
  if curl -sf http://127.0.0.1:8500/v1/status/leader >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
test -n "$ready"
echo "  consul answers on 8500"
cat > main.tf <<'EOF'
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

resource "random_pet" "site" {
  length = 2
}

output "site_name" {
  value = random_pet.site.id
}
EOF
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
test -s terraform.tfstate
echo "  local state present ($(wc -c < terraform.tfstate) bytes), site: $("$TF" output -raw site_name)"
echo

echo "== 1. The move: init -migrate-state =="
sed -i 's|terraform {|terraform {\n  backend "consul" {\n    address = "127.0.0.1:8500"\n    scheme  = "http"\n    path    = "book-labs/cap12"\n  }\n|' main.tf
"$TF" init -input=false -migrate-state -force-copy -no-color | grep -E 'Successfully configured' | sed 's/^/  /'
"$TF" state list | sed 's/^/  state list (via backend): /'
test ! -s terraform.tfstate
echo "  local terraform.tfstate: zero bytes (a courtesy .backup remains)"
curl -s http://127.0.0.1:8500/v1/kv/book-labs/cap12 | grep -q 'eyJ2ZXJzaW9uIjo0'
echo "  Consul KV holds the state (base64 starting eyJ2ZXJzaW9uIjo0 = version 4)"
echo

echo "== 2. The colleague, second act: same notebook =="
mkdir -p "$WORK/colleague"
cp main.tf "$WORK/colleague/"
cd "$WORK/colleague"
"$TF" init -input=false >/dev/null
"$TF" state list | grep -qx 'random_pet.site'
echo "  his state list shows MY resources (he attached, no migration needed)"
"$TF" plan -input=false -no-color | grep -E 'No changes' | sed 's/^/  his plan: /'
echo "  (chapter 11's incident cannot happen: one memory for everyone)"
echo

echo "== 3. The lock: one write at a time, by name =="
cd "$WORK/mine"
sed -i 's|resource "random_pet" "site" {|resource "time_sleep" "slow_work" {\n  create_duration = "20s"\n}\n\nresource "random_pet" "site" {|' main.tf
cp main.tf "$WORK/colleague/"
"$TF" apply -input=false -auto-approve >/dev/null 2>&1 &
apid=$!
sleep 4
cd "$WORK/colleague"
rc=0
"$TF" plan -input=false -no-color >lock.out 2>&1 || rc=$?
test "$rc" -ne 0
grep -E 'Error acquiring the state lock' lock.out | head -1 | sed 's/^/  /'
grep -E '^ +(ID|Operation|Who):' lock.out | sed 's/^ */    /'
echo "  (not a failure: the lock doing its trade — and it says who is inside)"
wait "$apid"
"$TF" plan -input=false -no-color | grep -E 'No changes' | sed 's/^/  apply done, his plan now: /'
echo

echo "== 4. One notebook, one destroy =="
"$TF" destroy -input=false -auto-approve >/dev/null
cd "$WORK/mine"
"$TF" plan -input=false -no-color > after.out
grep -E '2 to add' after.out >/dev/null
echo "  destroyed from the colleague's folder — my plan sees the same empty world"
echo "  (the notebook is one: whoever writes it, writes it for everyone)"
docker rm -f "$CONSUL" >/dev/null
echo "  noticeboard removed"
echo

echo "=== where the state lives is a decision — and the lock turns chaos into a queue ==="
