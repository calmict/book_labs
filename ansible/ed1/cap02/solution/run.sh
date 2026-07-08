#!/usr/bin/env bash
set -euo pipefail

# Chapter 2 solution — become the messenger: reproduce, by hand over SSH, the
# journey Ansible automates for every task, on a node that hosts nothing of ours.
#   0. build a managed node with ONLY sshd + python3 (no agent)
#   1. the three gifts: nothing of ours listening on the target
#   2. the journey frame by frame: copy the module, run it with the REMOTE python,
#      JSON on stdout, cleanup (no state left behind)
#   3. the role of Python: modules need it; raw (pure shell over SSH) does not
#   4. the interview: the module returns facts, like a tiny setup module
#
# Needs a running Docker engine, a standard ssh/scp client, and network access to
# install sshd+python3 in the node. Ephemeral key; guaranteed teardown on exit.

command -v docker  >/dev/null 2>&1 || { echo "ERROR: docker not found (see SETUP.md)"  >&2; exit 1; }
command -v ssh     >/dev/null 2>&1 || { echo "ERROR: ssh not found"  >&2; exit 1; }
command -v scp     >/dev/null 2>&1 || { echo "ERROR: scp not found"  >&2; exit 1; }

DIR=$(cd "$(dirname "$0")" && pwd)
NODE=cap02-node
PORT=2222
LAB=$(mktemp -d)
KEY="$LAB/lab_key"

cleanup() {
  docker rm -f "$NODE" >/dev/null 2>&1 || true
  rm -rf "$LAB"
}
trap cleanup EXIT

SSH=(ssh -p "$PORT" -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@127.0.0.1)
SCP=(scp -P "$PORT" -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

echo "== 0. Build a managed node with ONLY sshd + python3 (no agent) =="
docker rm -f "$NODE" >/dev/null 2>&1 || true
ssh-keygen -t ed25519 -N '' -f "$KEY" -q
docker run -d --name "$NODE" -p "$PORT:22" debian:12 sleep infinity >/dev/null
docker exec "$NODE" sh -c 'apt-get update -qq && apt-get install -y -qq openssh-server python3 >/dev/null 2>&1'
docker exec "$NODE" sh -c 'mkdir -p /run/sshd /root/.ssh && chmod 700 /root/.ssh'
docker exec -i "$NODE" sh -c 'cat > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys' < "$KEY.pub"
docker exec "$NODE" /usr/sbin/sshd
# wait for sshd to accept the key
ready=""
for _ in $(seq 1 15); do
  if "${SSH[@]}" true 2>/dev/null; then ready=1; break; fi
  sleep 1
done
test -n "$ready"
echo "  node up; we installed exactly two things on it:"
docker exec "$NODE" sh -c 'command -v sshd && command -v python3' | sed 's/^/    /'
echo

echo "== 1. The three gifts: what of ours runs on the target? =="
listening=$("${SSH[@]}" 'ps -e -o comm= | grep -E "sshd|ansible" | sort -u | tr "\n" " "')
echo "  processes of interest on the node: $listening"
echo "  -> sshd only; no agent, no daemon of ours (nothing to install, patch, or watch)"
echo

echo "== 2. The journey of a task, frame by frame =="
"${SSH[@]}" 'mkdir -p ~/.ansible/tmp'
echo "  1) tmp dir ready on the node"
"${SCP[@]}" "$DIR/module.py" root@127.0.0.1:.ansible/tmp/mod.py >/dev/null
echo "  2) module copied to the node"
out=$("${SSH[@]}" 'python3 ~/.ansible/tmp/mod.py')
echo "  3) run with the node's python -> $out"
"${SSH[@]}" 'rm -f ~/.ansible/tmp/mod.py'
left=$("${SSH[@]}" 'ls -A ~/.ansible/tmp')
[ -z "$left" ] || { echo "  UNEXPECTED: temp dir not clean: $left"; exit 1; }
echo "  4) cleaned up -> the temp file is gone, no state left on the node"
echo

echo "== 3. The role of Python: modules need it, raw does not =="
echo "$out" | grep -q '"python"' || { echo "  UNEXPECTED: the module produced no python fact"; exit 1; }
echo "  the module ran with the node's python (its version is in the facts above)"
raw=$("${SSH[@]}" 'echo "raw: just shell, no Python involved"')
echo "  raw over SSH -> $raw"
echo

echo "== 4. The interview: the module returns facts (a tiny setup module) =="
echo "$out" | grep -q '"ansible_facts"' || { echo "  UNEXPECTED: no ansible_facts in the output"; exit 1; }
echo "$out" | grep -q '"hostname"'      || { echo "  UNEXPECTED: no hostname fact"; exit 1; }
echo "  the node was interviewed: hostname/system/python came back as ansible_facts"
echo

echo "=== agentless, proven by hand: SSH in, run with the remote python, collect JSON, leave nothing behind ==="
