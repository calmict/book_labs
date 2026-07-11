#!/usr/bin/env bash
set -euo pipefail

# Chapter 17 solution — the shared repertoire: collections and FQCN, end to end.
#   0. ephemeral control node (venv + ansible-core) — NO managed nodes needed
#   1. install the pinned collection into a project-local collections/ folder
#   2. syntax-check
#   3. run: a community.general module (FQCN) writes the INI, next to builtins
#   4. the acid test: re-run -> changed=0
#
# Needs python3 (venv) and network (pip + galaxy.ansible.com). Everything runs
# with connection=local; only the ephemeral venv and temp files are created.

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found" >&2; exit 1; }

DIR=$(cd "$(dirname "$0")" && pwd)
START="$DIR/../start"
INV="$DIR/inventory.ini"
PLAY="$DIR/site.yml"
REQ="$DIR/requirements.yml"
TMP=$(mktemp -d)
VENV="$TMP/venv"
COLL="$TMP/collections"
CONF="$TMP/out/app.ini"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

recap_field() { grep -E "^$2 " "$1" | sed -n "s/.*$3=\([0-9]*\).*/\1/p" | head -1; }

echo "== 0. Control node (venv) — no managed nodes needed =="
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$START/requirements.txt"
AP="$VENV/bin/ansible-playbook"
AG="$VENV/bin/ansible-galaxy"
echo "  ansible-core in a venv; connection=local"
echo

echo "== 1. Install the pinned collection INTO the project (collections_path) =="
"$AG" collection install -r "$REQ" -p "$COLL" >/dev/null 2>&1
test -f "$COLL/ansible_collections/community/general/MANIFEST.json" \
  || { echo "  UNEXPECTED: community.general did not land in the project folder"; exit 1; }
"$AG" collection list -p "$COLL" 2>/dev/null | grep -E 'community\.general[[:space:]]+8\.6\.0' \
  || { echo "  UNEXPECTED: pinned version 8.6.0 not present"; exit 1; }
echo "  community.general 8.6.0 installed in the project's collections/ (not the global path)"
echo

# use OUR project-local collections for the rest
export ANSIBLE_COLLECTIONS_PATH="$COLL"

echo "== 2. syntax-check =="
"$AP" -i "$INV" "$PLAY" --syntax-check >/dev/null && echo "  syntax OK"
echo

echo "== 3. Run: a community.general module (FQCN) writes the INI =="
"$AP" -i "$INV" "$PLAY" -e conf_path="$CONF" >/dev/null 2>&1
grep -q '^\[server\]' "$CONF" || { echo "  UNEXPECTED: [server] section missing"; exit 1; }
grep -q '^port = 8080' "$CONF" || { echo "  UNEXPECTED: port key missing"; exit 1; }
echo "  community.general.ini_file wrote:"
sed 's/^/    /' "$CONF"
echo

echo "== 4. The acid test: re-run -> changed=0 =="
"$AP" -i "$INV" "$PLAY" -e conf_path="$CONF" 2>/dev/null > "$TMP/r2.txt"
c=$(recap_field "$TMP/r2.txt" control changed)
echo "  changed=$c"
[ "$c" = "0" ] || { echo "  UNEXPECTED: re-run should be changed=0"; exit 1; }
echo

echo "=== standing on giants, reproducibly: pinned in requirements.yml, kept in the project, called by FQCN ==="
