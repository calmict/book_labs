#!/usr/bin/env bash
set -euo pipefail

# Chapter 8 solution — the address book, from written to answering the roll:
#   0. ephemeral control node (venv + ansible-core) and the three target nodes
#   1. ansible-inventory --graph: the tree (prod -> web,db; edge range)
#   2. host patterns: web (2), web:!web2 (1), edge (3), ungrouped (0)
#   3. YAML == INI: the same graph from inventory.yml
#   4. group_vars: web1 inherits greeting from the web group
#   5. the roll call: ansible prod -m ping -> three pongs
#
# Needs python3 (venv), a Docker engine, an ssh client, and network (pip + apt).
# Ephemeral venv, key and containers; guaranteed teardown on exit.

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found" >&2; exit 1; }
command -v docker  >/dev/null 2>&1 || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }

DIR=$(cd "$(dirname "$0")" && pwd)
START="$DIR/../start"
INV="$DIR/inventory.ini"
YML="$DIR/inventory.yml"
TMP=$(mktemp -d)
VENV="$TMP/venv"

cleanup() {
  bash "$START/nodes.sh" down >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "== 0. Control node + three target nodes =="
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$START/requirements.txt"
bash "$START/nodes.sh" up >/dev/null
echo "  ansible-core in a venv; cap08-web1/web2/db1 up"
echo

AI="$VENV/bin/ansible-inventory"
AN="$VENV/bin/ansible"

echo "== 1. ansible-inventory --graph: the tree =="
"$AI" -i "$INV" --graph > "$TMP/graph.txt"
sed 's/^/  /' "$TMP/graph.txt"
for want in '@prod' '@web' '@db' web1 web2 db1 edge01.lab.internal edge03.lab.internal; do
  grep -q "$want" "$TMP/graph.txt" || { echo "  UNEXPECTED: $want missing from the graph"; exit 1; }
done
echo

# --list-hosts prints "  hosts (N):"; read N straight from that header.
count_hosts() { "$AN" -i "$INV" "$1" --list-hosts 2>/dev/null | sed -n 's/.*hosts (\([0-9]*\)).*/\1/p'; }
echo "== 2. Host patterns (resolved without connecting) =="
web=$(count_hosts web)
nweb=$(count_hosts 'web:!web2')
edge=$(count_hosts edge)
ung=$(count_hosts ungrouped)
echo "  web -> $web ; web:!web2 -> $nweb ; edge -> $edge ; ungrouped -> $ung"
[ "$web" -eq 2 ]  || { echo "  UNEXPECTED: web should be 2 hosts"; exit 1; }
[ "$nweb" -eq 1 ] || { echo "  UNEXPECTED: web:!web2 should be 1 host"; exit 1; }
[ "$edge" -eq 3 ] || { echo "  UNEXPECTED: edge range should be 3 hosts"; exit 1; }
[ "$ung" -eq 0 ]  || { echo "  UNEXPECTED: ungrouped should be empty"; exit 1; }
echo

echo "== 3. YAML == INI: the same address book, expressed in YAML =="
"$AI" -i "$YML" --graph > "$TMP/graph-yml.txt"
for want in '@prod' web1 web2 db1 edge02.lab.internal; do
  grep -q "$want" "$TMP/graph-yml.txt" || { echo "  UNEXPECTED: $want missing from the YAML graph"; exit 1; }
done
echo "  inventory.yml produces the same tree (prod -> web,db; edge range)"
echo

echo "== 4. group_vars: web1 inherits from the web group =="
"$AN" -i "$INV" web1 -m debug -a 'var=greeting' 2>/dev/null > "$TMP/gv.txt"
sed 's/^/  /' "$TMP/gv.txt"
grep -q 'hello from the web section' "$TMP/gv.txt" || { echo "  UNEXPECTED: web1 did not inherit greeting"; exit 1; }
echo

echo "== 5. The roll call: ansible prod -m ping =="
pongs=0
for _ in $(seq 1 10); do
  pongs=$("$AN" -i "$INV" prod -m ping 2>/dev/null | grep -c '"ping": "pong"' || true)
  [ "$pongs" -eq 3 ] && break
  sleep 2
done
echo "  prod -m ping -> $pongs pong(s)"
[ "$pongs" -eq 3 ] || { echo "  UNEXPECTED: expected 3 pongs from prod"; exit 1; }
echo

echo "=== the address book answers: web1/web2/db1 called by name, three pongs, no IP typed by hand ==="
