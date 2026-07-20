#!/usr/bin/env bash
# cap24 start - capabilities as least privilege, to complete. Three gaps
# (TODO 1..3): the three ping attempts (default caps, all dropped, only NET_RAW
# granted back) are missing, so the measurements are empty and the test fails.
# Throwaway containers (--rm).
set -euo pipefail

OUT="${1:?usage: icapabilities.sh OUTPUT_DIR}"
mkdir -p "$OUT"

# TODO 1 (24.1): default capabilities - ping works (NET_RAW is granted):
#     default=$(docker run --rm busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')
default=""

# TODO 2 (24.2): all capabilities dropped - no NET_RAW, ping fails:
#     dropall=$(docker run --rm --cap-drop ALL busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')
dropall=""

# TODO 3 (24.2): all dropped, only NET_RAW granted back - ping works, least privilege:
#     dropadd=$(docker run --rm --cap-drop ALL --cap-add NET_RAW busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')
dropadd=""

{
  echo "default=$default"
  echo "dropall=$dropall"
  echo "dropadd=$dropadd"
} > "$OUT/caps.txt"
