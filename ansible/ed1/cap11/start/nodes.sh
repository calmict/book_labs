#!/usr/bin/env bash
set -euo pipefail

# Chapter 11 — prepare (or tear down) the two nodes for privilege escalation.
#
#   bash nodes.sh up      build cap11-web1, cap11-web2
#   bash nodes.sh down     remove them
#
# Two caretaker policies:
#   web1 (port 2321) — connect as 'deploy', a standing pass:  NOPASSWD sudo
#   web2 (port 2322) — connect as 'secops', must show ID:     sudo with password
# Both nodes also carry 'appsvc' (a service account we become in place of root)
# and the 'acl' package (needed to become an unprivileged user). The lab (and
# its ephemeral key) live in /tmp/cap11-lab.

NET=cap11-net
LAB=/tmp/cap11-lab
KEY="$LAB/key"

# prepare <container> <connect-user> <sudoers-line> [sudo-password]
prepare() {
  local c="$1" u="$2" sudoers="$3" pw="${4:-}"
  docker exec "$c" sh -c 'apt-get update -qq && apt-get install -y -qq openssh-server python3 sudo acl >/dev/null 2>&1'
  docker exec "$c" sh -c "useradd -m -s /bin/bash $u"
  docker exec "$c" sh -c "mkdir -p /run/sshd /home/$u/.ssh && chmod 700 /home/$u/.ssh"
  docker exec -i "$c" sh -c "cat > /home/$u/.ssh/authorized_keys && chmod 600 /home/$u/.ssh/authorized_keys" < "$KEY.pub"
  docker exec "$c" sh -c "chown -R $u:$u /home/$u/.ssh"
  docker exec "$c" sh -c "echo '$sudoers' > /etc/sudoers.d/$u && chmod 440 /etc/sudoers.d/$u"
  if [ -n "$pw" ]; then docker exec "$c" sh -c "echo '$u:$pw' | chpasswd"; fi
  docker exec "$c" sh -c 'useradd -m -s /usr/sbin/nologin appsvc'
  docker exec "$c" /usr/sbin/sshd
}

up() {
  command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
  mkdir -p "$LAB"
  [ -f "$KEY" ] || ssh-keygen -t ed25519 -N '' -f "$KEY" -q
  docker network rm "$NET" >/dev/null 2>&1 || true
  docker network create "$NET" >/dev/null

  docker rm -f cap11-web1 >/dev/null 2>&1 || true
  docker run -d --name cap11-web1 --network "$NET" -p 2321:22 debian:12 sleep infinity >/dev/null
  prepare cap11-web1 deploy 'deploy ALL=(ALL) NOPASSWD:ALL' ''
  echo "  cap11-web1 up on 2321 (user: deploy, NOPASSWD sudo)"

  docker rm -f cap11-web2 >/dev/null 2>&1 || true
  docker run -d --name cap11-web2 --network "$NET" -p 2322:22 debian:12 sleep infinity >/dev/null
  prepare cap11-web2 secops 'secops ALL=(ALL) ALL' 'secops-pw'
  echo "  cap11-web2 up on 2322 (user: secops, sudo with password)"

  echo "target nodes ready (key: $KEY)"
}

down() {
  for n in cap11-web1 cap11-web2; do docker rm -f "$n" >/dev/null 2>&1 || true; done
  docker network rm "$NET" >/dev/null 2>&1 || true
  rm -rf "$LAB"
  echo "target nodes down."
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  *) echo "usage: $0 up|down" >&2; exit 2 ;;
esac
