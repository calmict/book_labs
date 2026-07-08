#!/usr/bin/env bash
set -euo pipefail

# Chapter 3 solution — open the hood on SSH, the channel all of Ansible rides on:
#   0. build a bastion (exposed) and a segregated target
#   1. key auth via a config alias (no password crosses the wire)
#   2. the permissions trap: a world-readable private key is refused
#   3. bastion / ProxyJump: the target is reachable only THROUGH the bastion
#   4. ControlMaster: the second connection reuses a master socket (Ansible's speed)
#   5. passphrase: an encrypted key cannot be read at rest without it
#
# Needs a running Docker engine, a standard ssh client, and network access to
# install sshd in the nodes. Ephemeral key; guaranteed teardown on exit.

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
command -v ssh    >/dev/null 2>&1 || { echo "ERROR: ssh not found" >&2; exit 1; }

DIR=$(cd "$(dirname "$0")" && pwd)
CFG="$DIR/ssh_config"
NET=cap03-net
BASTION=cap03-bastion
TARGET=cap03-target
PORT=2223
LAB=/tmp/cap03-lab
KEY="$LAB/key"

cleanup() {
  ssh -F "$CFG" -O exit bastion >/dev/null 2>&1 || true
  docker rm -f "$BASTION" "$TARGET" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  rm -f /tmp/cap03-cm-* 2>/dev/null || true
  rm -rf "$LAB"
}
trap cleanup EXIT

install_ssh() {
  docker exec "$1" sh -c 'apt-get update -qq && apt-get install -y -qq openssh-server >/dev/null 2>&1'
  docker exec "$1" sh -c 'mkdir -p /run/sshd /root/.ssh && chmod 700 /root/.ssh'
  docker exec -i "$1" sh -c 'cat > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys' < "$KEY.pub"
  docker exec "$1" /usr/sbin/sshd
}

echo "== 0. Build a bastion (exposed) and a segregated target =="
cleanup
mkdir -p "$LAB"
ssh-keygen -t ed25519 -N '' -f "$KEY" -q
docker network create "$NET" >/dev/null
docker run -d --name "$BASTION" --network "$NET" -p "$PORT:22" debian:12 sleep infinity >/dev/null
docker run -d --name "$TARGET"  --network "$NET"               debian:12 sleep infinity >/dev/null
install_ssh "$BASTION"
install_ssh "$TARGET"
ready=""
for _ in $(seq 1 15); do
  if ssh -F "$CFG" bastion true 2>/dev/null; then ready=1; break; fi
  sleep 1
done
test -n "$ready"
echo "  bastion up on host port $PORT; target segregated on $NET (no host port)"
echo

echo "== 1. Key auth via a config alias =="
bhost=$(ssh -F "$CFG" bastion 'hostname')
echo "  ssh -F ssh_config bastion -> logged in as key, host: $bhost (no password sent)"
echo

echo "== 2. The permissions trap =="
cp "$KEY" "$LAB/badkey"
chmod 644 "$LAB/badkey"
trap_out=$(ssh -i "$LAB/badkey" -p "$PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@127.0.0.1 true 2>&1 || true)
echo "$trap_out" | grep -qi 'UNPROTECTED PRIVATE KEY' || { echo "  UNEXPECTED: the 0644 key was not refused"; exit 1; }
echo "  a 0644 private key is refused: UNPROTECTED PRIVATE KEY FILE (private wants 600)"
echo

echo "== 3. Bastion / ProxyJump: the target is reachable only through the bastion =="
direct=$(ssh -F "$CFG" -o ProxyJump=none -o ConnectTimeout=5 target true 2>&1 || true)
echo "$direct" | grep -qi 'could not resolve' || { echo "  UNEXPECTED: direct target did not fail to resolve"; exit 1; }
echo "  direct to target: fails (name resolves only inside the lab network)"
thost=""
for _ in $(seq 1 10); do
  thost=$(ssh -F "$CFG" target 'hostname' 2>/dev/null) && [ -n "$thost" ] && break
  sleep 1
done
if [ -z "$thost" ] || [ "$thost" = "$bhost" ]; then echo "  UNEXPECTED: could not reach target via ProxyJump"; exit 1; fi
echo "  via ProxyJump bastion: on the target, host: $thost (jumped through $bhost)"
echo

echo "== 4. ControlMaster: the second connection reuses a master socket =="
ssh -F "$CFG" -O exit bastion >/dev/null 2>&1 || true    # close any master, measure fresh
for i in 1 2 3; do
  s=$(date +%s%N); ssh -F "$CFG" bastion true; e=$(date +%s%N)
  echo "  conn $i: $(( (e - s) / 1000000 )) ms"
done
ls /tmp/cap03-cm-* >/dev/null 2>&1 || { echo "  UNEXPECTED: no master socket was created"; exit 1; }
echo "  a master socket exists: conn 1 opened it, conns 2-3 reused it (near-zero setup)"
echo

echo "== 5. Passphrase: an encrypted key cannot be read at rest without it =="
ssh-keygen -t ed25519 -N 'a-passphrase' -f "$LAB/enckey" -q
if ssh-keygen -y -P '' -f "$LAB/enckey" >/dev/null 2>&1; then
  echo "  UNEXPECTED: the encrypted key was read without a passphrase"; exit 1
fi
echo "  without the passphrase the private key cannot be read (protected at rest)"
echo

echo "=== SSH, taken apart: public key on the servers, private key stays home, jump through the bastion, reuse the socket ==="
