#!/usr/bin/env bash
set -euo pipefail

# Chapter 15 — prepare (or tear down) the single node for the conditionals and
# loops lab. Conditionals and loops act per host, so one node is enough.
#
#   bash nodes.sh up      build cap15-web1 (sshd + python3 + sudo)
#   bash nodes.sh down     remove it
#
# You connect as the non-root 'deploy' user (passwordless sudo). Port: 2351.
# The lab (and its ephemeral key) live in /tmp/cap15-lab.

NET=cap15-net
LAB=/tmp/cap15-lab
KEY="$LAB/key"
NAME=cap15-web1
PORT=2351

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
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run -d --name "$NAME" --network "$NET" -p "$PORT:22" debian:12 sleep infinity >/dev/null
  prepare "$NAME"
  echo "  $NAME up on host port $PORT (user: deploy)"
  echo "target node ready (key: $KEY)"
}

down() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  rm -rf "$LAB"
  echo "target node down."
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  *) echo "usage: $0 up|down" >&2; exit 2 ;;
esac
