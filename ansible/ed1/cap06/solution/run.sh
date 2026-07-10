#!/usr/bin/env bash
set -euo pipefail

# Chapter 6 solution — pick up the baton and tune the players, end to end:
#   0. control node: create an isolated venv and install ansible-core into it
#   1. verify: ansible --version, the command family, ansible localhost -m ping -> pong
#   2. core vs package: with an isolated collection path, core alone is ~74 modules
#   3. target nodes: prepare cap06-web and cap06-db (sshd + python3), reachable over SSH
#
# Needs python3 (venv), a Docker engine, an ssh client, and network access
# (pip + apt). Ephemeral venv, key and containers; guaranteed teardown on exit.

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found" >&2; exit 1; }
command -v docker  >/dev/null 2>&1 || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
command -v ssh     >/dev/null 2>&1 || { echo "ERROR: ssh not found" >&2; exit 1; }

DIR=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d)
VENV="$TMP/venv"
NET=cap06-net
LAB=/tmp/cap06-lab
KEY="$LAB/key"
NODES=(cap06-web:2206 cap06-db:2207)

cleanup() {
  for entry in "${NODES[@]}"; do docker rm -f "${entry%%:*}" >/dev/null 2>&1 || true; done
  docker network rm "$NET" >/dev/null 2>&1 || true
  rm -rf "$LAB" "$TMP"
}
trap cleanup EXIT

echo "== 0. Control node: isolated venv + ansible-core =="
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$DIR/requirements.txt"
echo "  installed into an isolated venv (system Python untouched)"
echo

echo "== 1. Verify: version, the command family, the ping smoke test =="
"$VENV/bin/ansible" --version | head -1 | sed 's/^/  /'
for c in ansible ansible-playbook ansible-config ansible-doc ansible-galaxy; do
  test -x "$VENV/bin/$c" || { echo "  UNEXPECTED: $c missing"; exit 1; }
done
echo "  command family present: ansible, ansible-playbook, ansible-config, ansible-doc, ansible-galaxy"
"$VENV/bin/ansible" localhost -m ping | grep -q '"ping": "pong"' || { echo "  UNEXPECTED: localhost ping did not pong"; exit 1; }
echo "  ansible localhost -m ping -> pong (first module run, no SSH)"
echo

echo "== 2. Core vs package, in numbers =="
mkdir -p "$TMP/empty"
count=$(ANSIBLE_COLLECTIONS_PATH="$TMP/empty" "$VENV/bin/ansible-doc" -l 2>/dev/null | wc -l)
echo "  ansible-core alone exposes $count modules (all ansible.builtin)"
if [ "$count" -le 30 ] || [ "$count" -ge 300 ]; then echo "  UNEXPECTED: core module count $count out of expected range"; exit 1; fi
echo "  (the full 'ansible' package would add hundreds more via community collections)"
echo

echo "== 3. Target nodes: prepare cap06-web and cap06-db (sshd + python3) =="
mkdir -p "$LAB"
ssh-keygen -t ed25519 -N '' -f "$KEY" -q
docker network create "$NET" >/dev/null
for entry in "${NODES[@]}"; do
  name="${entry%%:*}"; port="${entry##*:}"
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker run -d --name "$name" --network "$NET" -p "$port:22" debian:12 sleep infinity >/dev/null
  docker exec "$name" sh -c 'apt-get update -qq && apt-get install -y -qq openssh-server python3 >/dev/null 2>&1'
  docker exec "$name" sh -c 'mkdir -p /run/sshd /root/.ssh && chmod 700 /root/.ssh'
  docker exec -i "$name" sh -c 'cat > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys' < "$KEY.pub"
  docker exec "$name" /usr/sbin/sshd
done
for entry in "${NODES[@]}"; do
  name="${entry%%:*}"; port="${entry##*:}"
  ok=""
  for _ in $(seq 1 15); do
    if ssh -p "$port" -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@127.0.0.1 true 2>/dev/null; then ok=1; break; fi
    sleep 1
  done
  test -n "$ok" || { echo "  UNEXPECTED: $name not reachable over SSH"; exit 1; }
  echo "  $name reachable over SSH on port $port (ready for the inventory in chapter 8)"
done
echo

echo "=== the baton is up: ansible-core in an isolated venv, and two target nodes ready for SSH ==="
