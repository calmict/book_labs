#!/usr/bin/env bash
# cap05 start - follow a request from the API to the kernel and map the execution
# chain. Uses a throwaway container and never restarts the shared daemon. Three
# gaps to fill (TODO 1..3). As written it records nothing useful.
set -euo pipefail

OUT="${1:?usage: lacatena.sh OUTPUT_DIR}"
mkdir -p "$OUT"
SOCK=/var/run/docker.sock
NAME="cap05-chain-$$"
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# TODO 1 (5.2): the CLI is just an API client. Ask the daemon its version over
#   the raw UNIX socket with curl, and record it. Fill in:
#     ver=$(curl -s --unix-socket "$SOCK" http://localhost/version \
#             | grep -o '"Version":"[^"]*"' | head -1 | cut -d'"' -f4)
#     echo "api_version=$ver" > "$OUT/chain.txt"
: > "$OUT/chain.txt"

docker run -d --rm --name "$NAME" busybox sleep 30 >/dev/null

# The same API lists the container (the same view as docker ps).
if curl -s --unix-socket "$SOCK" http://localhost/containers/json | grep -q "$NAME"; then
  echo "api_lists_container=yes" >> "$OUT/chain.txt"
else
  echo "api_lists_container=no" >> "$OUT/chain.txt"
fi

pid=$(docker inspect -f '{{.State.Pid}}' "$NAME")
ppid=$(awk '{print $4}' "/proc/$pid/stat")

# TODO 2 (5.5): record the container's PARENT process name. Read it from
#   /proc/<ppid>/comm - it should be a containerd-shim, the custodian, not
#   dockerd. Write:  parent_comm=<name>  to "$OUT/chain.txt".

# TODO 3 (5.4): record the GRANDPARENT process name. Read the parent's own parent
#   from /proc/<ppid>/stat (field 4), then its comm - it is systemd/containerd,
#   NOT dockerd, which is why restarting the daemon does not kill the container.
#   Write:  grandparent_comm=<name>  to "$OUT/chain.txt".
