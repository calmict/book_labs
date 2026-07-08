#!/usr/bin/env bash
set -euo pipefail

# Chapter 5 solution — idempotence made tangible with a tiny engine:
#   1. first apply: everything is [changed] (it acts)
#   2. second apply: the switch and the black swan go [ok] (idempotent),
#      the doorbell stays [changed] (never converges)
#   3. check mode: reports what WOULD change and writes nothing
#
# Pure files, no containers. Guaranteed cleanup on exit.

DIR=$(cd "$(dirname "$0")" && pwd)
ENGINE="$DIR/ensure.sh"
TMP=$(mktemp -d)
STATE="$TMP/state"
FRESH="$TMP/fresh"
trap 'rm -rf "$TMP"' EXIT

echo "== 1. First apply: everything is [changed] (it acts) =="
bash "$ENGINE" "$STATE" > "$TMP/out1"
sed 's/^/  /' "$TMP/out1"
grep -q 'added line: server=web'    "$TMP/out1" || { echo "  UNEXPECTED: switch did not add the line"; exit 1; }
grep -q 'rendered, content changed' "$TMP/out1" || { echo "  UNEXPECTED: render did not report changed"; exit 1; }
[ -f "$STATE/app.conf" ] || { echo "  UNEXPECTED: state file was not written"; exit 1; }
echo

echo "== 2. Second apply: idempotence (switch and black swan go [ok]) =="
bash "$ENGINE" "$STATE" > "$TMP/out2"
sed 's/^/  /' "$TMP/out2"
grep -q 'ok.*line already present: server=web' "$TMP/out2" || { echo "  UNEXPECTED: the switch is not idempotent"; exit 1; }
grep -q 'ok.*rendered, no change'              "$TMP/out2" || { echo "  UNEXPECTED: changed_when did not settle to ok"; exit 1; }
grep -q 'changed.*appended (again): deployed'  "$TMP/out2" || { echo "  UNEXPECTED: the doorbell should still be changed"; exit 1; }
echo "  -> switch: changed then ok; black swan: settled to ok; doorbell: still changed (never converges)"
echo

echo "== 3. Check mode: says WOULD, writes nothing =="
CHECK=1 bash "$ENGINE" "$FRESH" > "$TMP/outc"
sed 's/^/  /' "$TMP/outc"
grep -qi 'WOULD add line' "$TMP/outc" || { echo "  UNEXPECTED: check mode did not report a would-change"; exit 1; }
if [ -f "$FRESH/app.conf" ]; then echo "  UNEXPECTED: check mode wrote a state file"; exit 1; fi
echo "  check mode reported what would change and wrote no state file (dress rehearsal only)"
echo

echo "=== idempotence: a switch reports its colour and converges; a doorbell never does; changed_when judges the black swans ==="
