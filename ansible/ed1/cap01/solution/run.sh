#!/usr/bin/env bash
set -euo pipefail

# Chapter 1 solution — the three cracks of hand-scripting, end to end:
#   1. not repeatable : the naive script dies on its second run (useradd)
#   2. drift survives : a blind existence-guard is repeatable, yet leaves manual
#                       drift in place (repeatable is not convergent)
#   3. convergence    : a content-aware guard pulls the drifted server back to
#                       the desired state
#
# Needs a running Docker engine. Runs against three throwaway containers;
# guaranteed teardown (docker rm -f) on exit.

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }

DIR=$(cd "$(dirname "$0")" && pwd)
SERVERS=(cap01-server1 cap01-server2 cap01-server3)

cleanup() { docker rm -f "${SERVERS[@]}" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "== 0. Bring the fleet up (three servers) =="
cleanup
for s in "${SERVERS[@]}"; do
  docker run -d --name "$s" debian:12 sleep infinity >/dev/null
done
echo "  ${SERVERS[*]} up"
echo

echo "== 1. Crack 1: the naive script is not repeatable =="
naive_pass() {
  for s in "${SERVERS[@]}"; do
    docker exec "$s" useradd app || return 1
    docker exec "$s" sh -c 'echo "version=1.0" > /etc/app.conf' || return 1
  done
}
set +e
naive_pass >/dev/null 2>&1; first=$?
naive_pass >/dev/null 2>&1; second=$?
set -e
[ "$first" -eq 0 ]  || { echo "  UNEXPECTED: first naive run failed"; exit 1; }
[ "$second" -ne 0 ] || { echo "  UNEXPECTED: second naive run succeeded"; exit 1; }
echo "  first run ok; second run FAILED (useradd: user 'app' already exists) -> not repeatable"
echo

echo "== 2. Crack 3: a blind guard is repeatable but does NOT converge =="
docker exec cap01-server2 sh -c 'echo "version=9.9" > /etc/app.conf'
echo "  someone changed cap01-server2 by hand: version=9.9 (drift)"
for s in "${SERVERS[@]}"; do
  docker exec "$s" sh -c 'id -u app >/dev/null 2>&1 || useradd app'
  docker exec "$s" sh -c 'test -f /etc/app.conf || echo "version=1.0" > /etc/app.conf'
done
blind=$(docker exec cap01-server2 cat /etc/app.conf)
[ "$blind" = "version=9.9" ] || { echo "  UNEXPECTED: blind guard changed the file to [$blind]"; exit 1; }
echo "  blind guard re-run clean, yet cap01-server2 still: $blind -> the drift survived"
echo

echo "== 3. Convergence: the content-aware guard wins (solution/provision.sh) =="
docker exec cap01-server2 sh -c 'echo "version=9.9" > /etc/app.conf'
echo "  drift injected again on cap01-server2 (version=9.9)"
bash "$DIR/provision.sh"
conv=$(docker exec cap01-server2 cat /etc/app.conf)
[ "$conv" = "version=1.0" ] || { echo "  UNEXPECTED: server2 did not converge, got [$conv]"; exit 1; }
echo "  after re-run, cap01-server2: $conv -> converged, the desired state won"
echo

echo "=== repeatable is not convergent: the fix was to enforce the content, not just its existence ==="
