#!/usr/bin/env bash
set -euo pipefail

# Chapter 3 — bring the SSH lab up (or down): a bastion and a segregated target.
#
#   bash lab.sh up      build the network, the two nodes, and an ephemeral key
#   bash lab.sh down     remove everything
#
# Topology:
#   - bastion (cap03-bastion): on the lab network AND exposed on host port 2223
#   - target  (cap03-target):  on the lab network only, no published port; its
#                              name resolves only inside the network -> reachable
#                              from your machine solely through the bastion.
# The lab lives in /tmp/cap03-lab (key included); it is a throwaway drawer.

NET=cap03-net
BASTION=cap03-bastion
TARGET=cap03-target
PORT=2223
LAB=/tmp/cap03-lab
KEY="$LAB/key"

install_ssh() {
  # each node gets an ssh server and our public key; nothing else
  docker exec "$1" sh -c 'apt-get update -qq && apt-get install -y -qq openssh-server >/dev/null 2>&1'
  docker exec "$1" sh -c 'mkdir -p /run/sshd /root/.ssh && chmod 700 /root/.ssh'
  docker exec -i "$1" sh -c 'cat > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys' < "$KEY.pub"
  docker exec "$1" /usr/sbin/sshd
}

up() {
  command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
  mkdir -p "$LAB"
  [ -f "$KEY" ] || ssh-keygen -t ed25519 -N '' -f "$KEY" -q

  docker rm -f "$BASTION" "$TARGET" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  docker network create "$NET" >/dev/null

  docker run -d --name "$BASTION" --network "$NET" -p "$PORT:22" debian:12 sleep infinity >/dev/null
  docker run -d --name "$TARGET"  --network "$NET"               debian:12 sleep infinity >/dev/null
  install_ssh "$BASTION"
  install_ssh "$TARGET"

  echo "lab up:"
  echo "  bastion -> exposed on host port $PORT"
  echo "  target  -> segregated on network $NET (no host port, name resolves only inside)"
  echo "  key     -> $KEY (private) / $KEY.pub (public, already in both authorized_keys)"
  echo "use the SSH config with:  ssh -F start/ssh_config bastion   (and, once TODO 1 is done)  ssh -F start/ssh_config target"
}

down() {
  docker rm -f "$BASTION" "$TARGET" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  rm -f /tmp/cap03-cm-* 2>/dev/null || true
  rm -rf "$LAB"
  echo "lab down."
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  *) echo "usage: $0 up|down" >&2; exit 2 ;;
esac
