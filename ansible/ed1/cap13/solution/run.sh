#!/usr/bin/env bash
set -euo pipefail

# Chapter 13 solution — the chain of command: variable precedence, made visible.
#   0. ephemeral control node (venv + ansible-core) — NO managed nodes needed
#   1. syntax-check
#   2. real clashes (no -e): host beats group; the dict trap; the combine fix;
#      set_fact stickiness
#   3. -e wins over everything (level 22)
#   4. the tool: ansible-inventory --host shows the inventory-resolved vars
#
# Needs python3 (venv) and network (pip). Everything runs with connection=local,
# so there is nothing to tear down but the ephemeral venv.

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found" >&2; exit 1; }

DIR=$(cd "$(dirname "$0")" && pwd)
START="$DIR/../start"
INV="$DIR/inventory.ini"
PLAY="$DIR/site.yml"
TMP=$(mktemp -d)
VENV="$TMP/venv"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

need() { grep -Fq "$1" "$2" || { echo "  UNEXPECTED: missing '$1'"; exit 1; }; }

echo "== 0. Control node (venv) — no managed nodes needed =="
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$START/requirements.txt"
AP="$VENV/bin/ansible-playbook"
AI="$VENV/bin/ansible-inventory"
echo "  ansible-core in a venv; connection=local"
echo

echo "== 1. syntax-check =="
"$AP" -i "$INV" "$PLAY" --syntax-check >/dev/null && echo "  syntax OK"
echo

echo "== 2. Real clashes (no -e) =="
"$AP" -i "$INV" "$PLAY" 2>/dev/null | grep '"msg"' > "$TMP/out.txt"
sed 's/^/  /' "$TMP/out.txt"
# the specificity ladder: web1 keeps the group value, web2's host var wins
need 'web1: winner = group_vars(web)' "$TMP/out.txt"
need 'web2: winner = host_vars(web2)' "$TMP/out.txt"
# the dict trap: web2's partial override dropped a key
need "web1: bad_limits keys = ['max_connections', 'timeout_seconds']" "$TMP/out.txt"
need "web2: bad_limits keys = ['max_connections']" "$TMP/out.txt"
# the fix: combine preserves timeout_seconds on web2
need "web2: merged = {'max_connections': 500, 'timeout_seconds': 30}" "$TMP/out.txt"
# set_fact (19) beats the task var (17)
need 'web2: mode = set_fact_value' "$TMP/out.txt"
echo

echo "== 3. -e wins over everything (level 22) =="
"$AP" -i "$INV" "$PLAY" -e winner=EXTRA 2>/dev/null | grep 'winner =' > "$TMP/extra.txt"
sed 's/^/  /' "$TMP/extra.txt"
need 'web1: winner = EXTRA' "$TMP/extra.txt"
need 'web2: winner = EXTRA' "$TMP/extra.txt"
echo

echo "== 4. The tracing tool: ansible-inventory --host web2 =="
"$AI" -i "$INV" --host web2 > "$TMP/hostvars.txt"
sed 's/^/  /' "$TMP/hostvars.txt"
need '"winner": "host_vars(web2)"' "$TMP/hostvars.txt"
echo

echo "=== the chain of command holds: -e on top, role defaults at the bottom, and the list settles every tie ==="
