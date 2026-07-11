#!/usr/bin/env bash
set -euo pipefail

# Chapter 11 solution — the caretaker's keys: become in depth, end to end.
#   0. ephemeral control node (venv + ansible-core) and the two nodes
#   1. syntax-check
#   2. the two sudoers policies: web1 NOPASSWD, web2 password required
#   3. the password gate: web2 without the password -> "Missing sudo password"
#   4. full run: deploy -> root, secops -> root; the marker is owned by appsvc
#   5. the acid test: re-run -> changed=0
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

recap_field() { grep -E "^$2 " "$1" | sed -n "s/.*$3=\([0-9]*\).*/\1/p" | head -1; }

echo "== 0. Control node + two nodes =="
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$START/requirements.txt"
bash "$START/nodes.sh" up >/dev/null
AP="$VENV/bin/ansible-playbook"
AN="$VENV/bin/ansible"
echo "  ansible-core in a venv; cap11-web1 (deploy) / cap11-web2 (secops) up"
echo

for _ in $(seq 1 10); do
  pongs=$("$AN" -i "$INV" all -m ping 2>/dev/null | grep -c '"ping": "pong"' || true)
  [ "$pongs" -eq 2 ] && break
  sleep 2
done
[ "${pongs:-0}" -eq 2 ] || { echo "  UNEXPECTED: nodes not reachable"; exit 1; }

echo "== 1. syntax-check =="
"$AP" -i "$INV" "$PLAY" --syntax-check >/dev/null && echo "  syntax OK"
echo

echo "== 2. The caretaker's rulebook (sudoers) =="
echo "  web1: $(docker exec cap11-web1 cat /etc/sudoers.d/deploy)"
echo "  web2: $(docker exec cap11-web2 cat /etc/sudoers.d/secops)"
docker exec cap11-web1 cat /etc/sudoers.d/deploy | grep -q NOPASSWD || { echo "  UNEXPECTED: web1 should be NOPASSWD"; exit 1; }
docker exec cap11-web2 cat /etc/sudoers.d/secops | grep -q NOPASSWD && { echo "  UNEXPECTED: web2 should require a password"; exit 1; }
echo

echo "== 3. The password gate: web2 with no become password =="
# The play is meant to fail here, so tolerate the non-zero exit and read the file.
"$AP" -i "$INV" -l web2 -e 'ansible_become_password=' "$PLAY" > "$TMP/nopw.txt" 2>&1 || true
grep -i 'Missing sudo password' "$TMP/nopw.txt" | sed 's/^/  /'
grep -qi 'Missing sudo password' "$TMP/nopw.txt" || { echo "  UNEXPECTED: expected a missing-password failure"; exit 1; }
echo

echo "== 4. Full run: who became whom, and who owns the marker =="
"$AP" -i "$INV" "$PLAY" 2>/dev/null | tee "$TMP/run1.txt" | grep -E '\->' | sed 's/^/  /'
grep -q 'deploy -> root' "$TMP/run1.txt" || { echo "  UNEXPECTED: deploy did not become root"; exit 1; }
grep -q 'secops -> root' "$TMP/run1.txt" || { echo "  UNEXPECTED: secops did not become root"; exit 1; }
[ "$(recap_field "$TMP/run1.txt" web1 failed)" = "0" ] || { echo "  UNEXPECTED: web1 had failures"; exit 1; }
[ "$(recap_field "$TMP/run1.txt" web2 failed)" = "0" ] || { echo "  UNEXPECTED: web2 had failures"; exit 1; }
for c in cap11-web1 cap11-web2; do
  owner=$(docker exec "$c" stat -c '%U:%G' /srv/app/owner.txt)
  echo "  $c: /srv/app/owner.txt owned by $owner"
  [ "$owner" = "appsvc:appsvc" ] || { echo "  UNEXPECTED: marker should be owned by appsvc, not root"; exit 1; }
done
echo

echo "== 5. The acid test: re-run -> changed=0 =="
"$AP" -i "$INV" "$PLAY" 2>/dev/null > "$TMP/run2.txt"
for h in web1 web2; do
  c=$(recap_field "$TMP/run2.txt" "$h" changed)
  echo "  $h -> changed=$c"
  [ "$c" = "0" ] || { echo "  UNEXPECTED: $h should be changed=0 on re-run"; exit 1; }
done
echo

echo "=== the keys are lent, not owned: root when needed, appsvc for its own files, password at the gate ==="
