#!/usr/bin/env bash
# cap21 - solution test. A dynamic inventory discovers a fleet living inside an
# isolated docker-in-docker engine, groups it by label, reaches it over the
# docker connection, and a play targets a dynamically-created group. Every
# container touched lives inside the dind; no other container is ever affected.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

WORK=$(mktemp -d)
VENV="$WORK/venv"
COLL="$WORK/collections"
export DOCKER_HOST=tcp://127.0.0.1:23751
export ANSIBLE_COLLECTIONS_PATH="$COLL"

cleanup() {
  ./nodes.sh down >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

python3 -m venv "$VENV"
"$VENV/bin/pip" -q install -r requirements.txt
"$VENV/bin/ansible-galaxy" collection install -r requirements.yml -p "$COLL" >/dev/null
AI="$VENV/bin/ansible-inventory"
A="$VENV/bin/ansible"
AP="$VENV/bin/ansible-playbook"

# the sorted host list of a dynamic group, without connecting
membership() {
  "$A" -i inventory.docker.yml "$1" --list-hosts 2>/dev/null \
    | grep -oE 'cap21-[a-z0-9]+' | sort | paste -sd,
}

./nodes.sh up

# --- 1. the dynamic inventory discovers the live fleet (no names written) ---
"$AI" -i inventory.docker.yml --graph > "$WORK/graph.txt" 2>/dev/null
for h in cap21-web1 cap21-web2 cap21-db1; do
  grep -q "$h" "$WORK/graph.txt" \
    || { echo "UNEXPECTED: $h was not discovered" >&2; cat "$WORK/graph.txt"; exit 1; }
done
echo "OK 1 - the dynamic inventory discovered the live fleet"

# --- 2. keyed_groups grouped the fleet by label ---
[ "$(membership role_web)" = "cap21-web1,cap21-web2" ] \
  || { echo "UNEXPECTED: role_web = $(membership role_web)" >&2; exit 1; }
[ "$(membership role_db)" = "cap21-db1" ] \
  || { echo "UNEXPECTED: role_db = $(membership role_db)" >&2; exit 1; }
[ "$(membership env_prod)" = "cap21-db1,cap21-web1" ] \
  || { echo "UNEXPECTED: env_prod = $(membership env_prod)" >&2; exit 1; }
echo "OK 2 - keyed_groups built role_* and env_* from the labels"

# --- 3. groups built the conditional 'production' group ---
[ "$(membership production)" = "cap21-db1,cap21-web1" ] \
  || { echo "UNEXPECTED: production = $(membership production)" >&2; exit 1; }
echo "OK 3 - groups built 'production' from a Jinja2 condition (env=prod)"

# --- 4. compose made the web tier reachable over the docker connection ---
"$A" -i inventory.docker.yml role_web -m ping > "$WORK/ping.txt" 2>&1
[ "$(grep -c 'SUCCESS' "$WORK/ping.txt")" = "2" ] \
  || { echo "UNEXPECTED: web tier not reachable" >&2; cat "$WORK/ping.txt"; exit 1; }
echo "OK 4 - compose set the docker connection; the web tier answers ping"

# --- 5. the play (TODO 3) targeted only the dynamic role_web group ---
if ! "$AP" -i inventory.docker.yml site.yml > "$WORK/run1.txt" 2>&1; then
  echo "UNEXPECTED: the playbook failed" >&2
  cat "$WORK/run1.txt"
  exit 1
fi
for h in cap21-web1 cap21-web2; do
  docker exec "$h" test -f /etc/cap21-web.txt \
    || { echo "UNEXPECTED: the marker is missing on $h" >&2; exit 1; }
done
if docker exec cap21-db1 test -f /etc/cap21-web.txt 2>/dev/null; then
  echo "UNEXPECTED: db1 got the web marker (it should not be in role_web)" >&2
  exit 1
fi
echo "OK 5 - the play acted only on the dynamic role_web group (not db1)"

# --- 6. idempotence ---
"$AP" -i inventory.docker.yml site.yml > "$WORK/run2.txt" 2>&1
if ! grep -qE 'cap21-web1[[:space:]]+: ok=[0-9]+[[:space:]]+changed=0' "$WORK/run2.txt"; then
  echo "UNEXPECTED: the rerun was not idempotent" >&2
  grep 'cap21' "$WORK/run2.txt"
  exit 1
fi
echo "OK 6 - rerun is idempotent (changed=0)"

echo
echo "ALL CHECKS PASSED"
