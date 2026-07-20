#!/usr/bin/env bash
# cap24 solution - "the right keys, not all of them": capabilities as least
# privilege. The same operation - a ping, which needs the NET_RAW capability for its
# raw socket - is tried with three capability sets: the default set (works), all
# dropped (fails, even as root), and all dropped with only NET_RAW granted back
# (works). Throwaway containers (--rm), no restart, no privileges on the host.
set -euo pipefail

OUT="${1:?usage: icapabilities.sh OUTPUT_DIR}"
mkdir -p "$OUT"

# TODO 1 (24.1): default capabilities - ping works (NET_RAW is granted).
default=$(docker run --rm busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

# TODO 2 (24.2): all capabilities dropped - no NET_RAW, ping fails.
dropall=$(docker run --rm --cap-drop ALL busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

# TODO 3 (24.2): all dropped, only NET_RAW granted back - ping works, least privilege.
dropadd=$(docker run --rm --cap-drop ALL --cap-add NET_RAW busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

{
  echo "default=$default"
  echo "dropall=$dropall"
  echo "dropadd=$dropadd"
} > "$OUT/caps.txt"
