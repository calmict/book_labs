#!/usr/bin/env bash
set -euo pipefail

# Chapter 16 solution — the section: a reusable role, end to end.
#   0. ephemeral control node (venv + ansible-core) and one node
#   1. ansible-galaxy init: the skeleton a role is made of
#   2. syntax-check the three-line playbook
#   3. run the role: defaults vs vars (group beats defaults, role vars beats
#      group), files/templates resolved with no path, the handler fires
#   4. the acid test: re-run -> changed=0, handler does not fire again
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
N=cap16-web1

cleanup() {
  bash "$START/nodes.sh" down >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

recap_field() { grep -E "^$2 " "$1" | sed -n "s/.*$3=\([0-9]*\).*/\1/p" | head -1; }
present() { if ! docker exec "$N" test -e "$1"; then echo "  UNEXPECTED: $1 missing"; exit 1; fi; }
absent()  { if docker exec "$N" test -e "$1"; then echo "  UNEXPECTED: $1 present"; exit 1; fi; }
in_conf() { docker exec "$N" grep -Fq "$1" /etc/webapp/app.conf || { echo "  UNEXPECTED: '$1' not in app.conf"; exit 1; }; }
count() { docker exec "$N" sh -c "wc -l < /var/log/webapp-reloads.log 2>/dev/null || echo 0" | tr -d ' '; }

echo "== 0. Control node + one node =="
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$START/requirements.txt"
bash "$START/nodes.sh" up >/dev/null
AP="$VENV/bin/ansible-playbook"
AN="$VENV/bin/ansible"
AG="$VENV/bin/ansible-galaxy"
echo "  ansible-core in a venv; $N up (user: deploy)"
echo

echo "== 1. ansible-galaxy init: the skeleton of a role =="
"$AG" init "$TMP/scaffold_demo" >/dev/null
for d in defaults files handlers meta tasks templates vars; do
  test -d "$TMP/scaffold_demo/$d" || { echo "  UNEXPECTED: galaxy init missing $d/"; exit 1; }
done
echo "  created: defaults files handlers meta tasks templates vars (each with main.yml)"
echo

for _ in $(seq 1 10); do
  pongs=$("$AN" -i "$INV" web -m ping 2>/dev/null | grep -c '"ping": "pong"' || true)
  [ "$pongs" -eq 1 ] && break
  sleep 2
done
[ "${pongs:-0}" -eq 1 ] || { echo "  UNEXPECTED: node not reachable"; exit 1; }

echo "== 2. syntax-check the three-line playbook =="
"$AP" -i "$INV" "$PLAY" --syntax-check >/dev/null && echo "  syntax OK"
echo

echo "== 3. Run the role =="
"$AP" -i "$INV" "$PLAY" >/dev/null 2>&1
# defaults vs vars
in_conf "app_name = webfromgroup"       # group_vars (6) beat the role default (2)
in_conf "config_dir = /etc/webapp"       # role vars (15) beat group_vars (6)
absent /etc/WRONG                        # the group_vars config_dir was overridden
echo "  app_name=webfromgroup (group beats defaults); config_dir=/etc/webapp (vars beats group)"
# files/templates resolved from the role, no path
present /etc/webapp/app.conf
present /etc/webapp/motd
echo "  app.conf (template) and motd (file) resolved from the role's own folders"
# the handler fired once
[ "$(count)" = "1" ] || { echo "  UNEXPECTED: handler should have fired once"; exit 1; }
echo "  handler 'reload webapp' fired once (reloads.log = 1)"
echo

echo "== 4. The acid test: re-run -> changed=0, handler quiet =="
"$AP" -i "$INV" "$PLAY" 2>/dev/null > "$TMP/r2.txt"
c=$(recap_field "$TMP/r2.txt" web1 changed)
echo "  changed=$c ; reloads.log still $(count)"
[ "$c" = "0" ] || { echo "  UNEXPECTED: re-run should be changed=0"; exit 1; }
[ "$(count)" = "1" ] || { echo "  UNEXPECTED: handler should not fire on re-run"; exit 1; }
echo

echo "=== the section answers to its name: one tidy folder, a three-line playbook, reusable anywhere ==="
