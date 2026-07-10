#!/usr/bin/env bash
set -euo pipefail

# Chapter 10 — prepare (or tear down) the three nodes for the first playbook.
#
#   bash nodes.sh up      build cap10-web1, cap10-web2, cap10-db1
#   bash nodes.sh down     remove them
#
# You connect as the non-root 'deploy' user (passwordless sudo), so become:
# true escalates to root. Ports: web1 -> 2311, web2 -> 2312, db1 -> 2313.
# The lab (and its ephemeral key) live in /tmp/cap10-lab.

NET=cap10-net
LAB=/tmp/cap10-lab
KEY="$LAB/key"
NODES=(cap10-web1:2311 cap10-web2:2312 cap10-db1:2313)

prepare() {
  docker exec "$1" sh -c 'apt-get update -qq && apt-get install -y -qq openssh-server python3 sudo >/dev/null 2>&1'
  docker exec "$1" sh -c 'useradd -m -s /bin/bash deploy'
  docker exec "$1" sh -c 'mkdir -p /run/sshd /home/deploy/.ssh && chmod 700 /home/deploy/.ssh'
  docker exec -i "$1" sh -c 'cat > /home/deploy/.ssh/authorized_keys && chmod 600 /home/deploy/.ssh/authorized_keys' < "$KEY.pub"
  docker exec "$1" sh -c 'chown -R deploy:deploy /home/deploy/.ssh'
  docker exec "$1" sh -c 'echo "deploy ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/deploy && chmod 440 /etc/sudoers.d/deploy'
  docker exec "$1" /usr/sbin/sshd
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
    echo "  $name up on host port $port (user: deploy)"
  done
  echo "target nodes ready (key: $KEY)"
}

down() {
  for entry in "${NODES[@]}"; do docker rm -f "${entry%%:*}" >/dev/null 2>&1 || true; done
  docker network rm "$NET" >/dev/null 2>&1 || true
  rm -rf "$LAB"
  echo "target nodes down."
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  *) echo "usage: $0 up|down" >&2; exit 2 ;;
esac
