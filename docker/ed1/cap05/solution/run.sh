#!/usr/bin/env bash
# cap05 - solution test. Proves Docker is a chain of delegations, not one program:
# the CLI is an API client on the socket, and the container's parent is a
# containerd-shim (with systemd, not dockerd, above it) - which is exactly why the
# daemon can be restarted without killing the container (live-restore). Uses a
# throwaway container and never restarts the shared daemon: safe anywhere.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/lacatena.sh" "$WORK"
api_version=$(val "$WORK/chain.txt" api_version)
api_lists=$(val "$WORK/chain.txt" api_lists_container)
parent=$(val "$WORK/chain.txt" parent_comm)
grandparent=$(val "$WORK/chain.txt" grandparent_comm)

# 1. the socket is the API: a raw HTTP call returns the daemon version
if [ -z "$api_version" ]; then
  echo "UNEXPECTED: the socket did not answer with a version" >&2; exit 1
fi
echo "OK 1 - the CLI is an API client: the raw socket answers version $api_version"

# 2. the same API lists the container (same view as docker ps)
if [ "$api_lists" != "yes" ]; then
  echo "UNEXPECTED: the API did not list the running container" >&2; exit 1
fi
echo "OK 2 - the same API lists the running container (the CLI just formats this)"

# 3. the container's parent process is a containerd-shim, not dockerd
case "$parent" in
  *shim*) : ;;
  *) echo "UNEXPECTED: the container's parent is '$parent', not a shim" >&2; exit 1 ;;
esac
[ "$parent" = "dockerd" ] && { echo "UNEXPECTED: the container is a child of dockerd" >&2; exit 1; }
echo "OK 3 - the container's parent is the custodian shim ($parent), not the daemon"

# 4. above the shim is systemd/containerd, not dockerd: the container is NOT a
#    child of the daemon, so restarting dockerd would not kill it (live-restore)
if [ "$grandparent" = "dockerd" ]; then
  echo "UNEXPECTED: dockerd sits directly above the container ($grandparent)" >&2; exit 1
fi
echo "OK 4 - above the shim is $grandparent, not dockerd: this is why live-restore works"

echo
echo "ALL CHECKS PASSED"
