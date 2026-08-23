#!/usr/bin/env bash
# cap24 - solution test. Proves capabilities as least privilege: the same ping
# (which needs NET_RAW) works with the default capability set, fails with all
# capabilities dropped, and works again when only NET_RAW is granted back. Then it
# repeats the exercise on SYS_ADMIN, which mounting a filesystem needs; shows that
# seccomp is a second, independent barrier; and reads what --privileged changes.
# Throwaway containers, no restart, no privileges on the host: no host path is ever
# mounted into them.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/icapabilities.sh" "$WORK"
default=$(val "$WORK/caps.txt" default)
dropall=$(val "$WORK/caps.txt" dropall)
dropadd=$(val "$WORK/caps.txt" dropadd)
mount_default=$(val "$WORK/caps.txt" mount_default)
mount_added=$(val "$WORK/caps.txt" mount_added)
seccomp_mode=$(val "$WORK/caps.txt" seccomp_mode)
unshare_default=$(val "$WORK/caps.txt" unshare_default)
unshare_unconfined=$(val "$WORK/caps.txt" unshare_unconfined)
caps_default=$(val "$WORK/caps.txt" caps_default)
caps_privileged=$(val "$WORK/caps.txt" caps_privileged)
mount_privileged=$(val "$WORK/caps.txt" mount_privileged)

# 1. default capabilities: ping works (NET_RAW granted)
if [ "$default" != "OK" ]; then
  echo "UNEXPECTED: ping failed with default capabilities (default=$default)" >&2; exit 1
fi
echo "OK 1 - default capabilities: ping works (NET_RAW granted)"

# 2. all dropped: ping fails (no NET_RAW, even as root)
if [ "$dropall" != "FAIL" ]; then
  echo "UNEXPECTED: ping worked with --cap-drop ALL (dropall=$dropall)" >&2; exit 1
fi
echo "OK 2 - --cap-drop ALL: ping fails (no NET_RAW, even as root)"

# 3. only NET_RAW granted back: ping works again (least privilege)
if [ "$dropadd" != "OK" ]; then
  echo "UNEXPECTED: ping failed with only NET_RAW added back (dropadd=$dropadd)" >&2; exit 1
fi
echo "OK 3 - --cap-drop ALL --cap-add NET_RAW: ping works (only the needed key)"

# 4. a sharper capability: mounting a filesystem needs SYS_ADMIN, not in the default set
if [ "$mount_default" != "DENIED" ] || [ "$mount_added" != "MOUNTED" ]; then
  echo "UNEXPECTED: mount is '$mount_default' by default and '$mount_added' with SYS_ADMIN," >&2
  echo "            expected DENIED and MOUNTED" >&2; exit 1
fi
echo "OK 4 - SYS_ADMIN: mounting a filesystem is $mount_default by default, $mount_added when granted back"

# 5. seccomp is a second barrier, independent of the capabilities
if [ "$seccomp_mode" != "2" ]; then
  echo "UNEXPECTED: Seccomp mode is $seccomp_mode, expected 2 (a filter is loaded)" >&2; exit 1
fi
if [ "$unshare_default" != "BLOCKED" ] || [ "$unshare_unconfined" != "ALLOWED" ]; then
  echo "UNEXPECTED: unshare is '$unshare_default' with the default profile and" >&2
  echo "            '$unshare_unconfined' without it, expected BLOCKED and ALLOWED" >&2; exit 1
fi
echo "OK 5 - seccomp: a filter is loaded (mode $seccomp_mode) and refuses the syscall on its own -"
echo "       unshare is $unshare_default by default and $unshare_unconfined unconfined, same capabilities"

# 6. --privileged removes both barriers at once
if [ "$caps_privileged" = "$caps_default" ] || [ "$mount_privileged" != "MOUNTED" ]; then
  echo "UNEXPECTED: privileged caps=$caps_privileged (default $caps_default), mount=$mount_privileged" >&2; exit 1
fi
echo "OK 6 - --privileged: the effective set goes from $caps_default to $caps_privileged,"
echo "       and the mount is $mount_privileged without asking for any capability"

echo
echo "ALL CHECKS PASSED"
