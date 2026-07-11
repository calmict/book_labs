#!/usr/bin/env bash
set -euo pipefail

# Chapter 14 solution — the recall at the end of rehearsal: handlers, counted.
#   0. ephemeral control node (venv + ansible-core) and the two nodes
#   1. syntax-check
#   2. run 1 (fresh): configs created -> two tasks notify -> each handler runs
#      ONCE (dedup) via listen -> reloads.log = metrics.log = 1
#   3. run 2 (no change): handlers do NOT fire -> still 1
#   4. run 3 (-e greeting=ciao): config changed -> handlers fire -> 2
#   5. run 4 (-e force_reload=true): changed_when forces the trigger -> 3
#
# Needs python3 (venv), a Docker engine, an ssh client, and network (pip + apt).
# Ephemeral venv, key and containers; guaranteed teardown on exit.

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found" >&2; exit 1; }
command -v docker  >/dev/null 2>&1 || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }

DIR=$(cd "$(dirname "$0")" && pwd)
START="$DIR/../start"
INV="$DIR/inventory.ini"
PLAY="$DIR/site.yml"
TMP=$(mktemp -d)
VENV="$TMP/venv"

cleanup() {
  bash "$START/nodes.sh" down >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

count() { docker exec "$1" sh -c "wc -l < /var/log/myapp/$2 2>/dev/null || echo 0" | tr -d ' '; }
expect() { # <container> <file> <expected>
  local got; got=$(count "$1" "$2")
  [ "$got" = "$3" ] || { echo "  UNEXPECTED on $1: $2 has $got lines, expected $3"; exit 1; }
}

echo "== 0. Control node + two nodes =="
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$START/requirements.txt"
bash "$START/nodes.sh" up >/dev/null
AP="$VENV/bin/ansible-playbook"
AN="$VENV/bin/ansible"
echo "  ansible-core in a venv; cap14-web1/web2 up (user: deploy)"
echo

for _ in $(seq 1 10); do
  pongs=$("$AN" -i "$INV" web -m ping 2>/dev/null | grep -c '"ping": "pong"' || true)
  [ "$pongs" -eq 2 ] && break
  sleep 2
done
[ "${pongs:-0}" -eq 2 ] || { echo "  UNEXPECTED: nodes not reachable"; exit 1; }

echo "== 1. syntax-check =="
"$AP" -i "$INV" "$PLAY" --syntax-check >/dev/null && echo "  syntax OK"
echo

echo "== 2. Run 1 (fresh): two tasks notify, each handler fires ONCE =="
"$AP" -i "$INV" "$PLAY" >/dev/null 2>&1
for h in cap14-web1 cap14-web2; do expect "$h" reloads.log 1; expect "$h" metrics.log 1; done
echo "  reloads.log = 1, metrics.log = 1 on both nodes (dedup + listen)"
echo

echo "== 3. Run 2 (no change): handlers must NOT fire =="
"$AP" -i "$INV" "$PLAY" >/dev/null 2>&1
for h in cap14-web1 cap14-web2; do expect "$h" reloads.log 1; done
echo "  reloads.log still 1 on both nodes (no change, no reload)"
echo

echo "== 4. Run 3 (-e greeting=ciao): config changed -> handlers fire =="
"$AP" -i "$INV" "$PLAY" -e greeting=ciao >/dev/null 2>&1
for h in cap14-web1 cap14-web2; do expect "$h" reloads.log 2; done
echo "  reloads.log = 2 on both nodes"
echo

echo "== 5. Run 4 (-e greeting=ciao -e force_reload=true): changed_when triggers =="
"$AP" -i "$INV" "$PLAY" -e greeting=ciao -e force_reload=true >/dev/null 2>&1
for h in cap14-web1 cap14-web2; do expect "$h" reloads.log 3; done
echo "  reloads.log = 3 on both nodes (config unchanged, but changed_when forced it)"
echo

echo "=== four runs, three reloads: the service reloads only when it must ==="
