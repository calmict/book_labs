#!/usr/bin/env bash
# cap02 - builds a rootless container from Linux namespaces alone and verifies
# PID 1, private hostname, isolated network and namespace inodes. The contrast
# run drops the namespace flags. No runtime, downloaded rootfs or sudo is used.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
value() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/handmade.sh" "$WORK"
inside_pid=$(value "$WORK/inside.txt" inside_pid)
inside_name=$(value "$WORK/inside.txt" inside_hostname)
host_name=$(value "$WORK/host.txt" host_hostname)
interfaces=$(value "$WORK/inside.txt" inside_interfaces)

[ "$inside_pid" = 1 ] || { echo "UNEXPECTED: isolated shell has PID $inside_pid" >&2; exit 1; }
echo "OK 1 - the hand-made container starts with its shell as PID 1"
if [ "$inside_name" != hand-made-container ] || [ "$host_name" = hand-made-container ]; then echo "UNEXPECTED: hostname isolation failed" >&2; exit 1; fi
echo "OK 2 - the UTS namespace keeps the host hostname unchanged"
[ "$interfaces" = lo, ] || { echo "UNEXPECTED: isolated network contains $interfaces" >&2; exit 1; }
echo "OK 3 - the network namespace contains only its private loopback interface"
for ns in pid uts net user; do
  [ "$(value "$WORK/host.txt" "host_${ns}ns")" != "$(value "$WORK/inside.txt" "inside_${ns}ns")" ] || { echo "UNEXPECTED: $ns namespace inode did not change" >&2; exit 1; }
done
echo "OK 4 - pid, uts, net and user namespace inodes differ from the host"

plain_pid=$(unshare --user --map-root-user --fork sh -c 'echo $$')
[ "$plain_pid" -gt 1 ] || { echo "UNEXPECTED: shell without PID isolation is PID 1" >&2; exit 1; }
echo "OK 5 - the gate bites: dropping PID isolation removes the PID 1 view"
echo
echo "ALL CHECKS PASSED"
