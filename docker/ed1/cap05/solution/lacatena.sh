#!/usr/bin/env bash
# cap05 solution - "the chain and the custodian": follow a request from the API
# to the kernel. Talk to the daemon directly through its socket (the CLI is just
# an API client), then map the execution chain and prove the container's parent
# is a containerd-shim - not dockerd - which is exactly why restarting the daemon
# does not kill it (live-restore). Uses a throwaway container and never restarts
# the shared daemon, so it is safe to run anywhere.
set -euo pipefail

OUT="${1:?usage: lacatena.sh OUTPUT_DIR}"
mkdir -p "$OUT"
SOCK=/var/run/docker.sock
NAME="cap05-chain-$$"
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# 1) The CLI is just an API client: ask the daemon its version over the raw socket.
ver=$(curl -s --unix-socket "$SOCK" http://localhost/version \
        | grep -o '"Version":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "api_version=$ver" > "$OUT/chain.txt"

# A throwaway container to inspect.
docker run -d --rm --name "$NAME" busybox sleep 30 >/dev/null

# 2) The same API lists the container (the same view as docker ps).
if curl -s --unix-socket "$SOCK" http://localhost/containers/json | grep -q "$NAME"; then
  echo "api_lists_container=yes" >> "$OUT/chain.txt"
else
  echo "api_lists_container=no" >> "$OUT/chain.txt"
fi

# 3) The chain: the container process, its parent and its grandparent on the host.
pid=$(docker inspect -f '{{.State.Pid}}' "$NAME")
ppid=$(awk '{print $4}' "/proc/$pid/stat")
gppid=$(awk '{print $4}' "/proc/$ppid/stat")
echo "parent_comm=$(cat "/proc/$ppid/comm")"       >> "$OUT/chain.txt"
echo "grandparent_comm=$(cat "/proc/$gppid/comm")" >> "$OUT/chain.txt"
