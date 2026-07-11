#!/usr/bin/env bash
# cap18 - managed node: one host reached as 'secops', whose sudo needs a
# PASSWORD (no NOPASSWD). That password is the secret this chapter locks away
# in an Ansible vault. Same shape as the web2 node of chapter 11.
set -euo pipefail

NODE=cap18-web1
PORT=2371
LAB=/tmp/cap18-lab
IMAGE=debian:12

up() {
  mkdir -p "$LAB"
  if [ ! -f "$LAB/key" ]; then
    ssh-keygen -t ed25519 -N '' -f "$LAB/key" -q
  fi
  local pub
  pub=$(cat "$LAB/key.pub")

  docker rm -f "$NODE" >/dev/null 2>&1 || true
  docker run -d --name "$NODE" -p "$PORT:22" "$IMAGE" sleep infinity >/dev/null

  docker exec "$NODE" bash -c '
    set -e
    apt-get update -qq >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      openssh-server python3 sudo >/dev/null
    mkdir -p /run/sshd
    useradd -m -s /bin/bash secops
    echo "secops:secops-pw" | chpasswd
    # sudo WITH password (no NOPASSWD): the password is the secret to protect.
    echo "secops ALL=(ALL) ALL" > /etc/sudoers.d/secops
    chmod 440 /etc/sudoers.d/secops
    mkdir -p /home/secops/.ssh
    echo "'"$pub"'" > /home/secops/.ssh/authorized_keys
    chown -R secops:secops /home/secops/.ssh
    chmod 700 /home/secops/.ssh
    chmod 600 /home/secops/.ssh/authorized_keys
    /usr/sbin/sshd
  '
  echo "$NODE up on port $PORT (user secops, sudo with password)"
}

down() {
  docker rm -f "$NODE" >/dev/null 2>&1 || true
  rm -rf "$LAB"
  echo "$NODE down"
}

case "${1:-up}" in
  up) up ;;
  down) down ;;
  *) echo "usage: $0 [up|down]" >&2; exit 2 ;;
esac
