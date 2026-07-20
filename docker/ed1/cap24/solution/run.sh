#!/usr/bin/env bash
# cap24 - solution test. Proves capabilities as least privilege: the same ping
# (which needs NET_RAW) works with the default capability set, fails with all
# capabilities dropped, and works again when only NET_RAW is granted back.
# Throwaway containers, no restart, no privileges on the host.
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

echo
echo "ALL CHECKS PASSED"
