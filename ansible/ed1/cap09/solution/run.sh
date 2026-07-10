#!/usr/bin/env bash
set -euo pipefail

# Chapter 9 solution — the cue, not the score: ad-hoc commands end to end.
#   0. ephemeral control node (venv + ansible-core) and the two web nodes
#   1. anatomy + the roll call: ansible web -m ping
#   2. command vs shell: the pipe is literal with command, executed with shell
#   3. become: whoami is 'deploy' without -b, 'root' with -b
#   4. copy is a switch: CHANGED the first run, ok (changed:false) the second
#   5. file + become: /etc/cap09.d, idempotent too (changed -> ok)
#   6. setup: one fact (the distribution) per node
#   7. forks: two hosts in parallel vs --forks 1 in a row (measured)
#   8. the morning round: the reader's runbook.sh runs to completion
#
# Needs python3 (venv), a Docker engine, an ssh client, and network (pip + apt).
# Ephemeral venv, key and containers; guaranteed teardown on exit.

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found" >&2; exit 1; }
command -v docker  >/dev/null 2>&1 || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }

DIR=$(cd "$(dirname "$0")" && pwd)
START="$DIR/../start"
INV="$START/inventory.ini"
TMP=$(mktemp -d)
VENV="$TMP/venv"

cleanup() {
  bash "$START/nodes.sh" down >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "== 0. Control node + two web nodes =="
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$START/requirements.txt"
bash "$START/nodes.sh" up >/dev/null
AN="$VENV/bin/ansible"
echo "  ansible-core in a venv; cap09-web1/web2 up (user: deploy)"
echo

echo "== 1. The roll call: ansible web -m ping =="
pongs=0
for _ in $(seq 1 10); do
  pongs=$("$AN" -i "$INV" web -m ping 2>/dev/null | grep -c '"ping": "pong"' || true)
  [ "$pongs" -eq 2 ] && break
  sleep 2
done
echo "  web -m ping -> $pongs pong(s)"
[ "$pongs" -eq 2 ] || { echo "  UNEXPECTED: expected 2 pongs from web"; exit 1; }
echo

echo "== 2. command vs shell: the pipe =="
"$AN" -i "$INV" web1 -m command -a 'echo ciao | wc -c' 2>/dev/null > "$TMP/cmd.txt"
"$AN" -i "$INV" web1 -m shell   -a 'echo ciao | wc -c' 2>/dev/null > "$TMP/shl.txt"
sed 's/^/  command: /' "$TMP/cmd.txt"
sed 's/^/  shell:   /' "$TMP/shl.txt"
grep -q 'ciao | wc -c' "$TMP/cmd.txt" || { echo "  UNEXPECTED: command should print the pipe literally"; exit 1; }
grep -qx '5' "$TMP/shl.txt"            || { echo "  UNEXPECTED: shell should execute the pipe (5 bytes)"; exit 1; }
echo

echo "== 3. become: whoami without and with -b =="
"$AN" -i "$INV" web1 -m command -a whoami 2>/dev/null > "$TMP/who.txt"
"$AN" -i "$INV" web1 -b -m command -a whoami 2>/dev/null > "$TMP/whob.txt"
echo "  without -b -> $(grep -vE '\|' "$TMP/who.txt" | tr -d ' ')"
echo "  with -b    -> $(grep -vE '\|' "$TMP/whob.txt" | tr -d ' ')"
grep -qw deploy "$TMP/who.txt"  || { echo "  UNEXPECTED: without -b should be deploy"; exit 1; }
grep -qw root   "$TMP/whob.txt" || { echo "  UNEXPECTED: with -b should be root"; exit 1; }
echo

echo "== 4. copy is a switch: CHANGED then ok =="
"$AN" -i "$INV" web1 -b -m copy -a "src=$START/motd dest=/etc/motd mode=0644" 2>/dev/null > "$TMP/cp1.txt"
"$AN" -i "$INV" web1 -b -m copy -a "src=$START/motd dest=/etc/motd mode=0644" 2>/dev/null > "$TMP/cp2.txt"
echo "  first run  -> $(grep -oE 'CHANGED|SUCCESS' "$TMP/cp1.txt" | head -1)"
echo "  second run -> $(grep -oE 'CHANGED|SUCCESS' "$TMP/cp2.txt" | head -1)"
grep -q '"changed": true'  "$TMP/cp1.txt" || { echo "  UNEXPECTED: first copy should be changed"; exit 1; }
grep -q '"changed": false' "$TMP/cp2.txt" || { echo "  UNEXPECTED: second copy should be unchanged"; exit 1; }
echo

echo "== 5. file + become: /etc/cap09.d, idempotent =="
"$AN" -i "$INV" web1 -b -m file -a 'path=/etc/cap09.d state=directory mode=0755' 2>/dev/null > "$TMP/f1.txt"
"$AN" -i "$INV" web1 -b -m file -a 'path=/etc/cap09.d state=directory mode=0755' 2>/dev/null > "$TMP/f2.txt"
grep -q '"changed": true'  "$TMP/f1.txt" || { echo "  UNEXPECTED: first file should be changed"; exit 1; }
grep -q '"changed": false' "$TMP/f2.txt" || { echo "  UNEXPECTED: second file should be unchanged"; exit 1; }
echo "  /etc/cap09.d created (changed), then confirmed (ok) on the second run"
echo

echo "== 6. setup: one fact per node =="
"$AN" -i "$INV" web -m setup -a 'filter=ansible_distribution' 2>/dev/null > "$TMP/fact.txt"
grep -q 'ansible_distribution' "$TMP/fact.txt" || { echo "  UNEXPECTED: setup did not return the fact"; exit 1; }
echo "  ansible_distribution -> $(grep -m1 '"ansible_distribution"' "$TMP/fact.txt" | tr -d ' ,')"
echo

echo "== 7. forks: parallel vs --forks 1 =="
t0=$(date +%s); "$AN" -i "$INV" web -a 'sleep 3' >/dev/null 2>&1; t1=$(date +%s); par=$((t1 - t0))
t0=$(date +%s); "$AN" -i "$INV" web --forks 1 -a 'sleep 3' >/dev/null 2>&1; t1=$(date +%s); ser=$((t1 - t0))
echo "  parallel (default) -> ${par}s ; serial (--forks 1) -> ${ser}s"
[ "$ser" -gt "$par" ] || { echo "  UNEXPECTED: serial should take longer than parallel"; exit 1; }
echo

echo "== 8. The morning round: the reader's runbook.sh =="
( cd "$START" && PATH="$VENV/bin:$PATH" bash "$DIR/runbook.sh" inventory.ini ) >/dev/null 2>&1
echo "  runbook.sh completed (ping, uptime, copy, file, setup)"
echo

echo "=== the cue lands: one module, the whole fleet — switches settle, campanelli always ring ==="
