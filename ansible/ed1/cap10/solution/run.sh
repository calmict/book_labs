#!/usr/bin/env bash
set -euo pipefail

# Chapter 10 solution — the written score: the first playbook end to end.
#   0. ephemeral control node (venv + ansible-core) and the three nodes
#   1. syntax-check: read the score without touching the nodes
#   2. first run: two plays, the recap (web ok=4 changed=3, db ok=2 changed=1)
#   3. the acid test: re-run -> changed=0 everywhere (idempotence)
#   4. tags: --tags structure runs only the directory tasks; the copy is skipped
#
# Needs python3 (venv), a Docker engine, an ssh client, and network (pip + apt).
# Ephemeral venv, key and containers; guaranteed teardown on exit.

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found" >&2; exit 1; }
command -v docker  >/dev/null 2>&1 || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }

DIR=$(cd "$(dirname "$0")" && pwd)
START="$DIR/../start"
INV="$START/inventory.ini"
PLAY="$DIR/site.yml"
TMP=$(mktemp -d)
VENV="$TMP/venv"

cleanup() {
  bash "$START/nodes.sh" down >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

# recap_field <file> <host> <field>  ->  the integer after "<field>="
recap_field() { grep -E "^$2 " "$1" | sed -n "s/.*$3=\([0-9]*\).*/\1/p" | head -1; }

echo "== 0. Control node + three nodes =="
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$START/requirements.txt"
bash "$START/nodes.sh" up >/dev/null
AP="$VENV/bin/ansible-playbook"
AN="$VENV/bin/ansible"
echo "  ansible-core in a venv; cap10-web1/web2/db1 up (user: deploy)"
echo

# wait for sshd on all three before the first play
for _ in $(seq 1 10); do
  pongs=$("$AN" -i "$INV" all -m ping 2>/dev/null | grep -c '"ping": "pong"' || true)
  [ "$pongs" -eq 3 ] && break
  sleep 2
done
[ "${pongs:-0}" -eq 3 ] || { echo "  UNEXPECTED: nodes not reachable"; exit 1; }

echo "== 1. syntax-check: read the score, touch nothing =="
"$AP" -i "$INV" "$PLAY" --syntax-check >/dev/null && echo "  syntax OK"
echo

echo "== 2. First run: two plays, the recap =="
"$AP" -i "$INV" "$PLAY" 2>/dev/null | tee "$TMP/run1.txt" | grep -E '^PLAY \[|^PLAY RECAP' | sed 's/^/  /'
w1c=$(recap_field "$TMP/run1.txt" web1 changed); w1o=$(recap_field "$TMP/run1.txt" web1 ok)
d1c=$(recap_field "$TMP/run1.txt" db1 changed);  d1o=$(recap_field "$TMP/run1.txt" db1 ok)
echo "  web1 -> ok=$w1o changed=$w1c ; db1 -> ok=$d1o changed=$d1c"
if [ "$w1o" != "4" ] || [ "$w1c" != "3" ]; then echo "  UNEXPECTED: web1 should be ok=4 changed=3"; exit 1; fi
if [ "$d1o" != "2" ] || [ "$d1c" != "1" ]; then echo "  UNEXPECTED: db1 should be ok=2 changed=1"; exit 1; fi
echo

echo "== 3. The acid test: re-run -> changed=0 =="
"$AP" -i "$INV" "$PLAY" 2>/dev/null > "$TMP/run2.txt"
for h in web1 web2 db1; do
  c=$(recap_field "$TMP/run2.txt" "$h" changed)
  echo "  $h -> changed=$c"
  [ "$c" = "0" ] || { echo "  UNEXPECTED: $h should be changed=0 on re-run"; exit 1; }
done
echo

echo "== 4. Tags: --tags structure runs only the directory tasks =="
"$AP" -i "$INV" "$PLAY" --tags structure 2>/dev/null > "$TMP/tags.txt"
grep -q 'Ensure the app directory exists' "$TMP/tags.txt" || { echo "  UNEXPECTED: the structure task should run"; exit 1; }
grep -q 'Deploy the message of the day'   "$TMP/tags.txt" && { echo "  UNEXPECTED: the content task should be skipped"; exit 1; }
echo "  ran the file/directory tasks; skipped the copy (content) tasks"
echo

echo "=== the score plays: two plays, one command, re-run without fear (changed=0) ==="
