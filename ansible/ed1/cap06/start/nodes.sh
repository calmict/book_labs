#!/usr/bin/env bash
set -euo pipefail

# Chapter 6 — prepare (or tear down) the target nodes for the coming chapters.
#
#   bash nodes.sh up      build cap06-web and cap06-db (sshd + python3)
#   bash nodes.sh down     remove them
#
# A managed node needs only SSH and Python (agentless, chapter 2). Each node
# publishes its SSH port on the host so you can reach it directly:
#   cap06-web -> host port 2206
#   cap06-db  -> host port 2207
# The lab (and its ephemeral key) live in /tmp/cap06-lab.

NET=cap06-net
LAB=/tmp/cap06-lab
KEY="$LAB/key"
NODES=(cap06-web:2206 cap06-db:2207)

prepare() {
  local name="$1"
  docker exec "$name" sh -c 'apt-get update -qq && apt-get install -y -qq openssh-server python3 >/dev/null 2>&1'
  docker exec "$name" sh -c 'mkdir -p /run/sshd /root/.ssh && chmod 700 /root/.ssh'
  docker exec -i "$name" sh -c 'cat > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys' < "$KEY.pub"
  docker exec "$name" /usr/sbin/sshd
}

up() {
  command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
  mkdir -p "$LAB"
  [ -f "$KEY" ] || ssh-keygen -t ed25519 -N '' -f "$KEY" -q
  docker network rm "$NET" >/dev/null 2>&1 || true
  docker network create "$NET" >/dev/null
  for entry in "${NODES[@]}"; do
    name="${entry%%:*}"; port="${entry##*:}"
    docker rm -f "$name" >/dev/null 2>&1 || true
    docker run -d --name "$name" --network "$NET" -p "$port:22" debian:12 sleep infinity >/dev/null
    prepare "$name"
    echo "  $name up on host port $port"
  done
  echo "target nodes ready (key: $KEY)"
}

down() {
  for entry in "${NODES[@]}"; do
    docker rm -f "${entry%%:*}" >/dev/null 2>&1 || true
  done
  docker network rm "$NET" >/dev/null 2>&1 || true
  rm -rf "$LAB"
  echo "target nodes down."
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  *) echo "usage: $0 up|down" >&2; exit 2 ;;
esac
