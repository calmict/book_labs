#!/usr/bin/env bash
set -euo pipefail

# Chapter 8 solution — one translator, two sites, end to end:
#   0. build the second datacenter (dind, a real separate engine on tcp);
#   1. one apply, two worlds: the same nginx placed in both engines via
#      the aliased provider and the provider meta-argument;
#   2. who sees what: 4 resources in one state, one container per engine;
#   3. both sites answer over HTTP;
#   4. the asymmetric demolition: destroy empties both worlds through
#      their lines, but the hand-made datacenter survives — and is then
#      removed by hand.
#
# Needs a running Docker engine able to launch a privileged container,
# and free ports 8091/8092/23750. Runs in a throwaway temp dir;
# guaranteed cleanup (destroy + dind removal + rm) on exit.

DIR=$(cd "$(dirname "$0")" && pwd)
DC=cap08-frankfurt-dc

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
  docker rm -f "$DC" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

cp "$DIR/main.tf" "$WORK/"
cd "$WORK"

echo "== 0. Building the second datacenter (dind) =="
docker rm -f "$DC" >/dev/null 2>&1 || true
docker run -d --name "$DC" --privileged -e DOCKER_TLS_CERTDIR="" \
  -p 127.0.0.1:23750:2375 -p 127.0.0.1:8092:8092 docker:27-dind >/dev/null
ready=""
for i in $(seq 1 30); do
  if docker -H tcp://127.0.0.1:23750 info >/dev/null 2>&1; then
    echo "  Frankfurt answers after ~$((i * 2))s"
    ready=1
    break
  fi
  sleep 2
done
test -n "$ready"
echo "  Milan engine:     $(docker info --format '{{.ServerVersion}}')"
echo "  Frankfurt engine: $(docker -H tcp://127.0.0.1:23750 info --format '{{.ServerVersion}}')"
echo "  (two engines, two inventories — really separate worlds)"
echo

echo "== 1. One apply, two worlds =="
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve -no-color | grep -E '^Apply complete' | sed 's/^/  /'
echo

echo "== 2. Who sees what =="
echo "  state list (one state, four resources):"
"$TF" state list | sed 's/^/    /'
test "$("$TF" state list | wc -l)" -eq 4
docker ps --format '{{.Names}}' | grep -qx 'cap08-web-milan'
echo "  Milan engine sees:     cap08-web-milan (plus the dind itself)"
docker -H tcp://127.0.0.1:23750 ps --format '{{.Names}}' | grep -qx 'cap08-web-frankfurt'
echo "  Frankfurt engine sees: cap08-web-frankfurt (and nothing else)"
echo "  (placement is code — the provider meta-argument — not an implicit context)"
echo

echo "== 3. Both sites answer =="
for port in 8091 8092; do
  ok=""
  for _ in $(seq 1 10); do
    if curl -sS --max-time 5 "http://127.0.0.1:${port}" 2>/dev/null | grep -q 'Welcome to nginx'; then
      ok=1
      break
    fi
    sleep 2
  done
  test -n "$ok"
  echo "  http://127.0.0.1:${port} -> Welcome to nginx!"
done
echo

echo "== 4. The asymmetric demolition =="
"$TF" destroy -input=false -auto-approve -no-color | grep -E '^Destroy complete' | sed 's/^/  /'
test -z "$(docker -H tcp://127.0.0.1:23750 ps -aq)"
echo "  Frankfurt engine: empty (its nginx removed through the aliased line)"
test -z "$(docker ps -q --filter name=cap08-web)"
docker ps --format '{{.Names}}' | grep -qx "$DC"
echo "  but $DC is still alive: hand-made, so not tofu's to demolish"
docker rm -f "$DC" >/dev/null
echo "  removed by hand — the symmetry is yours to close"
echo

echo "=== one translator, two telephones, and the secrets always outside the code ==="
