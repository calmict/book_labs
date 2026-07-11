#!/usr/bin/env bash
set -euo pipefail

# Chapter 15 solution — if, and for each: conditionals and loops, end to end.
#   0. ephemeral control node (venv + ansible-core) and one node
#   1. syntax-check
#   2. run 1 (dev): loops create users+dirs; 3 tasks skip; first-run fires
#   3. run 2 (dev, re-run): the first-run task now SKIPS (sentinel)
#   4. run 3 (prod + metrics + tuning): the three conditional files appear
#   5. run 4 (prod only): metrics stays off — the AND needs both
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
N=cap15-web1

cleanup() {
  bash "$START/nodes.sh" down >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

recap_field() { grep -E "^$2 " "$1" | sed -n "s/.*$3=\([0-9]*\).*/\1/p" | head -1; }
present() { if ! docker exec "$N" test -e "$1"; then echo "  UNEXPECTED: $1 missing"; exit 1; fi; }
absent()  { if docker exec "$N" test -e "$1"; then echo "  UNEXPECTED: $1 present"; exit 1; fi; }
shell_is() { # <user> <expected shell>
  local got; got=$(docker exec "$N" sh -c "getent passwd $1 | cut -d: -f7")
  [ "$got" = "$2" ] || { echo "  UNEXPECTED: $1 shell is '$got', expected '$2'"; exit 1; }
}

echo "== 0. Control node + one node =="
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$START/requirements.txt"
bash "$START/nodes.sh" up >/dev/null
AP="$VENV/bin/ansible-playbook"
AN="$VENV/bin/ansible"
echo "  ansible-core in a venv; $N up (user: deploy)"
echo

for _ in $(seq 1 10); do
  pongs=$("$AN" -i "$INV" web -m ping 2>/dev/null | grep -c '"ping": "pong"' || true)
  [ "$pongs" -eq 1 ] && break
  sleep 2
done
[ "${pongs:-0}" -eq 1 ] || { echo "  UNEXPECTED: node not reachable"; exit 1; }

echo "== 1. syntax-check =="
"$AP" -i "$INV" "$PLAY" --syntax-check >/dev/null && echo "  syntax OK"
echo

echo "== 2. Run 1 (dev): loops act, conditionals skip, first-run fires =="
"$AP" -i "$INV" "$PLAY" 2>/dev/null > "$TMP/r1.txt"
echo "  recap: skipped=$(recap_field "$TMP/r1.txt" web1 skipped)"
shell_is websvc /bin/bash
shell_is batchsvc /usr/sbin/nologin
for d in logs cache run; do present "/srv/app/$d"; done
absent /srv/app/PRODUCTION
absent /srv/app/metrics.enabled
absent /srv/app/tuning.conf
present /srv/app/firstrun.txt
[ "$(recap_field "$TMP/r1.txt" web1 skipped)" = "3" ] || { echo "  UNEXPECTED: expected 3 skips in dev"; exit 1; }
echo "  users (2 shells) + dirs created; PRODUCTION/metrics/tuning skipped; firstrun present"
echo

echo "== 3. Run 2 (dev, re-run): first-run task now SKIPS (sentinel present) =="
"$AP" -i "$INV" "$PLAY" 2>/dev/null > "$TMP/r2.txt"
echo "  recap: skipped=$(recap_field "$TMP/r2.txt" web1 skipped)"
[ "$(recap_field "$TMP/r2.txt" web1 skipped)" = "4" ] || { echo "  UNEXPECTED: first-run should also skip now"; exit 1; }
echo "  the sentinel makes the first-run task skip (4 skips)"
echo

echo "== 4. Run 3 (prod + metrics + tuning): the conditional files appear =="
"$AP" -i "$INV" "$PLAY" -e app_env=prod -e enable_metrics=true -e tuning_profile=fast 2>/dev/null >/dev/null
present /srv/app/PRODUCTION
present /srv/app/metrics.enabled
present /srv/app/tuning.conf
echo "  PRODUCTION, metrics.enabled and tuning.conf all created"
echo

echo "== 5. Run 4 (prod only): metrics stays off — the AND needs both =="
docker exec "$N" rm -f /srv/app/metrics.enabled
"$AP" -i "$INV" "$PLAY" -e app_env=prod 2>/dev/null >/dev/null
absent /srv/app/metrics.enabled
present /srv/app/PRODUCTION
echo "  PRODUCTION present, metrics.enabled NOT recreated (enable_metrics is false)"
echo

echo "=== the playbook decided and repeated: same file, dev or prod, by how you call it ==="
