#!/usr/bin/env bash
# cap02 - solution test. Builds a process isolated in several namespaces at once
# and proves each room is real by comparing the namespace inodes inside vs on the
# host: PID (PID 1 inside), UTS (isolated hostname), MNT (a private mount the host
# cannot see), NET (a near-mute private stack), USER (root inside but rootless).
# Then the gate bites: drop --net and the process shares the host's network
# namespace again. No Docker, no sudo.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/lestanze.sh" "$WORK"
inside_pid=$(val "$WORK/inside.txt" inside_pid)
inside_hostname=$(val "$WORK/inside.txt" inside_hostname)
inside_uts=$(val "$WORK/inside.txt" inside_uts)
inside_mnt=$(val "$WORK/inside.txt" inside_mnt)
inside_net=$(val "$WORK/inside.txt" inside_net)
inside_marker=$(val "$WORK/inside.txt" inside_marker)
inside_ifaces=$(val "$WORK/inside.txt" inside_net_ifaces)
inside_id=$(val "$WORK/inside.txt" inside_id)
host_uts=$(val "$WORK/host.txt" host_uts)
host_mnt=$(val "$WORK/host.txt" host_mnt)
host_net=$(val "$WORK/host.txt" host_net)

# 1. PID: our shell is PID 1 of a new PID namespace
[ "$inside_pid" = "1" ] || { echo "UNEXPECTED: inside PID is $inside_pid, not 1" >&2; exit 1; }
echo "OK 1 - PID: inside our shell is process number 1"

# 2. UTS: hostname changed inside, and the uts inode differs from the host's
if [ "$inside_hostname" != "sei-stanze" ] || [ "$inside_uts" = "$host_uts" ]; then
  echo "UNEXPECTED: UTS not isolated (host=$host_uts inside=$inside_uts $inside_hostname)" >&2; exit 1
fi
echo "OK 2 - UTS: hostname isolated (sei-stanze), uts namespace differs from host"

# 3. MNT: a private tmpfs mount visible inside, and a different mnt namespace
if [ "$inside_marker" != "mounted" ] || [ "$inside_mnt" = "$host_mnt" ]; then
  echo "UNEXPECTED: MNT not isolated (marker=$inside_marker host=$host_mnt inside=$inside_mnt)" >&2; exit 1
fi
[ -e /mnt/marker ] && { echo "UNEXPECTED: the private mount leaked to the host" >&2; exit 1; }
echo "OK 3 - MNT: a private mount exists inside and is invisible to the host"

# 4. NET: a different net namespace, near-mute (only loopback, no routable ifaces)
if [ "$inside_net" = "$host_net" ] || [ "$inside_ifaces" -gt 2 ]; then
  echo "UNEXPECTED: NET not isolated (host=$host_net inside=$inside_net ifaces=$inside_ifaces)" >&2; exit 1
fi
echo "OK 4 - NET: private, near-mute network stack (host $host_net vs inside $inside_net)"

# 5. USER: we are root (uid 0) inside, yet we used no sudo - the fake root
[ "$inside_id" = "0" ] || { echo "UNEXPECTED: inside uid is $inside_id, not 0" >&2; exit 1; }
[ "$(id -u)" != "0" ] && echo "OK 5 - USER: root inside (uid 0) while a plain, rootless user outside" \
  || echo "OK 5 - USER: root inside (uid 0) via the USER namespace"

# 6. the gate bites: without --net the process shares the host's net namespace
nonet=$(unshare --user --map-root-user --uts --pid --fork --mount-proc \
          bash -c 'readlink /proc/self/ns/net' 2>/dev/null || echo FAILED)
if [ "$nonet" != "$host_net" ]; then
  echo "UNEXPECTED: without --net the process did not share the host net namespace ($nonet)" >&2; exit 1
fi
echo "OK 6 - drop --net and the network room is gone (shares host $host_net)"

echo
echo "ALL CHECKS PASSED"
