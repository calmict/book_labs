#!/usr/bin/env bash
set -euo pipefail

# Chapter 12 solution — annotations on the score: variables end to end.
#   0. ephemeral control node (venv + ansible-core) and the two nodes
#   1. syntax-check
#   2. render the config: the five value types, the host_vars port override,
#      the fact (hostname), the default (log_level), the set_fact (workers)
#   3. -e wins: app_name=canary on the command line beats group_vars
#   4. the acid test: re-run -> changed=0
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
cfg()  { docker exec "$1" cat /etc/myapp/config.ini; }
line() { docker exec "$1" sh -c "grep -E '^$2 ' /etc/myapp/config.ini"; }
want() { # <container> <key> <expected>
  local got; got=$(docker exec "$1" sh -c "grep -E '^$2 = ' /etc/myapp/config.ini | head -1")
  [ "$got" = "$2 = $3" ] || { echo "  UNEXPECTED on $1: '$got' != '$2 = $3'"; exit 1; }
}

echo "== 0. Control node + two nodes =="
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$START/requirements.txt"
bash "$START/nodes.sh" up >/dev/null
AP="$VENV/bin/ansible-playbook"
AN="$VENV/bin/ansible"
echo "  ansible-core in a venv; cap12-web1/web2 up (user: deploy)"
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

echo "== 2. Render: types, host override, fact, default, set_fact =="
"$AP" -i "$INV" "$PLAY" >/dev/null 2>&1
echo "  --- web1 config.ini ---"; cfg cap12-web1 | sed 's/^/    /'
# the five types + the default, from group_vars
want cap12-web1 app_name orchestra
want cap12-web1 port 8080
want cap12-web1 debug False
want cap12-web1 features "metrics, tracing, healthcheck"
want cap12-web1 max_connections 200
want cap12-web1 log_level info
# host_vars/web2.yml overrides the port
want cap12-web2 port 8081
echo "  web1 port=8080 (group), web2 port=8081 (host_vars wins)"
# the fact: hostname line mentions the node's own hostname
h1=$(docker exec cap12-web1 hostname)
line cap12-web1 '#' | grep -q "$h1" || { echo "  UNEXPECTED: fact ansible_hostname not rendered"; exit 1; }
# set_fact: workers == 2 * nproc
np=$(docker exec cap12-web1 nproc)
want cap12-web1 workers "$((np * 2))"
echo "  fact hostname rendered; workers=$((np * 2)) (2 x $np CPUs, via set_fact)"
echo

echo "== 3. -e wins: app_name=canary beats group_vars =="
"$AP" -i "$INV" "$PLAY" -e app_name=canary >/dev/null 2>&1
want cap12-web1 app_name canary
want cap12-web2 app_name canary
echo "  app_name=canary on both nodes (extra var beats group_vars)"
echo

echo "== 4. The acid test: re-run (same -e) -> changed=0 =="
"$AP" -i "$INV" "$PLAY" -e app_name=canary 2>/dev/null > "$TMP/run2.txt"
for h in web1 web2; do
  c=$(recap_field "$TMP/run2.txt" "$h" changed)
  echo "  $h -> changed=$c"
  [ "$c" = "0" ] || { echo "  UNEXPECTED: $h should be changed=0 on re-run"; exit 1; }
done
echo

echo "=== one score, many performances: group, host, command line and facts all feed one config ==="
