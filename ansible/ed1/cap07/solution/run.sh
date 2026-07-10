#!/usr/bin/env bash
set -euo pipefail

# Chapter 7 solution — the rulebook and where Ansible finds it, end to end:
#   0. ephemeral control node (venv + ansible-core)
#   1. the hierarchy: cwd cfg wins over system; ANSIBLE_CONFIG wins over all
#   2. the completed cfg through ansible-config dump --only-changed
#      (core settings in the base dump; pipelining only with -t all)
#   3. the trap: in a world-writable directory the cwd cfg is IGNORED (warning)
#   4. the production rulebook (solution/ansible.cfg) parses and is inspectable
#
# Pure configuration, no containers. Needs python3 (venv) and network for pip.
# Ephemeral venv and workdirs; guaranteed cleanup on exit.

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found" >&2; exit 1; }

DIR=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d)
VENV="$TMP/venv"
WORK="$TMP/project"
trap 'rm -rf "$TMP"' EXIT

echo "== 0. Ephemeral control node (venv + ansible-core) =="
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$DIR/../start/requirements.txt"
"$VENV/bin/ansible" --version | head -1 | sed 's/^/  /'
echo

echo "== 1. The hierarchy: the nearest stand wins =="
mkdir -p "$WORK"
cd "$WORK"
before=$("$VENV/bin/ansible" --version | grep 'config file')
case "$before" in
  *"$WORK"*) echo "  UNEXPECTED: no cfg written yet, but the workdir cfg is active"; exit 1 ;;
esac
echo "  no project cfg yet -> $before"
# the completed exercise rulebook (TODO 1 + TODO 2 done)
cat > ansible.cfg <<'CFG'
[defaults]
inventory = ./inventory.ini
forks = 10
host_key_checking = False

[privilege_escalation]
become = True
become_method = sudo

[ssh_connection]
pipelining = True
CFG
after=$("$VENV/bin/ansible" --version | grep 'config file')
case "$after" in
  *"$WORK/ansible.cfg"*) echo "  ./ansible.cfg created -> the cwd cfg is now active" ;;
  *) echo "  UNEXPECTED: cwd cfg not picked up: $after"; exit 1 ;;
esac
printf '[defaults]\nforks = 99\n' > "$TMP/explicit.cfg"
env_cfg=$(ANSIBLE_CONFIG="$TMP/explicit.cfg" "$VENV/bin/ansible" --version | grep 'config file')
case "$env_cfg" in
  *"explicit.cfg"*) echo "  ANSIBLE_CONFIG set -> the env cfg wins over the cwd one" ;;
  *) echo "  UNEXPECTED: ANSIBLE_CONFIG did not win: $env_cfg"; exit 1 ;;
esac
echo

echo "== 2. dump --only-changed: only the deltas, each with its source =="
dump=$("$VENV/bin/ansible-config" dump --only-changed 2>/dev/null)
echo "$dump" > "$TMP/dump.txt"
sed 's/^/  /' "$TMP/dump.txt"
grep -q 'DEFAULT_FORKS.*= 10'        "$TMP/dump.txt" || { echo "  UNEXPECTED: forks missing from dump"; exit 1; }
grep -q 'HOST_KEY_CHECKING.*= False' "$TMP/dump.txt" || { echo "  UNEXPECTED: host_key_checking missing"; exit 1; }
grep -q 'DEFAULT_BECOME.*= True'     "$TMP/dump.txt" || { echo "  UNEXPECTED: become missing"; exit 1; }
if grep -qi 'pipelining' "$TMP/dump.txt"; then
  echo "  UNEXPECTED: pipelining in the BASE dump (it should need -t all)"; exit 1
fi
"$VENV/bin/ansible-config" dump --only-changed -t all 2>/dev/null | grep -i 'pipelining' > "$TMP/pipe.txt" || true
grep -q '= True' "$TMP/pipe.txt" || { echo "  UNEXPECTED: pipelining not visible with -t all"; exit 1; }
echo "  -> core deltas in the base dump; pipelining (a connection-plugin setting) only with -t all"
echo

echo "== 3. The trap: a world-writable directory gets its cfg IGNORED =="
mkdir -p "$TMP/open-room"
cp ansible.cfg "$TMP/open-room/"
chmod 777 "$TMP/open-room"
cd "$TMP/open-room"
"$VENV/bin/ansible" --version > "$TMP/trap.out" 2> "$TMP/trap.err" || true
grep -qi 'world writable' "$TMP/trap.err" || { echo "  UNEXPECTED: no world-writable warning"; exit 1; }
if grep -q "open-room/ansible.cfg" "$TMP/trap.out"; then
  echo "  UNEXPECTED: the world-writable cfg was used"; exit 1
fi
echo "  WARNING raised and the local cfg ignored -> fell back to the next stand"
cd "$WORK"
echo

echo "== 4. The production rulebook parses and is inspectable =="
ANSIBLE_CONFIG="$DIR/ansible.cfg" "$VENV/bin/ansible-config" dump --only-changed 2>/dev/null > "$TMP/prod.txt"
grep -q 'DEFAULT_FORKS.*= 10' "$TMP/prod.txt" || { echo "  UNEXPECTED: production cfg did not parse"; exit 1; }
if grep -q 'HOST_KEY_CHECKING' "$TMP/prod.txt"; then
  echo "  UNEXPECTED: production cfg should NOT touch host_key_checking"; exit 1
fi
echo "  solution/ansible.cfg parses; note: it does NOT disable host_key_checking (lab-only setting)"
echo

echo "=== the nearest stand wins outright; dump --only-changed tells you which; a world-writable stand is refused ==="
