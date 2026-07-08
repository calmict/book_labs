#!/usr/bin/env bash
set -euo pipefail

# Chapter 2 — bring a managed node up (or down).
#
# "Agentless" in practice: the node gets ONLY sshd + python3 — no Ansible, no
# agent, no daemon of ours. That is the whole point of this chapter. The node is
# a throwaway container; the SSH key is ephemeral (kept in a temp dir, never in
# the repo).
#
#   bash node.sh up     build the node, print the ssh command
#   bash node.sh down    remove the node and the key

NODE=cap02-node
PORT=2222
LAB="${TMPDIR:-/tmp}/cap02-lab"
KEY="$LAB/lab_key"

up() {
  command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
  mkdir -p "$LAB"
  [ -f "$KEY" ] || ssh-keygen -t ed25519 -N '' -f "$KEY" -q

  docker rm -f "$NODE" >/dev/null 2>&1 || true
  docker run -d --name "$NODE" -p "$PORT:22" debian:12 sleep infinity >/dev/null

  # the ONLY two things we install: an ssh server and python. No agent.
  docker exec "$NODE" sh -c 'apt-get update -qq && apt-get install -y -qq openssh-server python3 >/dev/null 2>&1'
  docker exec "$NODE" sh -c 'mkdir -p /run/sshd /root/.ssh && chmod 700 /root/.ssh'
  docker exec -i "$NODE" sh -c 'cat > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys' < "$KEY.pub"
  docker exec "$NODE" /usr/sbin/sshd

  echo "managed node up: only sshd + python3 installed, nothing else."
  echo "connect from this control node with:"
  echo "  ssh -p $PORT -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1"
  echo "copy a file to it with:"
  echo "  scp -P $PORT -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null <file> root@127.0.0.1:<dest>"
}

down() {
  docker rm -f "$NODE" >/dev/null 2>&1 || true
  rm -rf "$LAB"
  echo "managed node down."
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  *) echo "usage: $0 up|down" >&2; exit 2 ;;
esac
