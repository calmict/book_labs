#!/usr/bin/env bash
# cap07 - solution test. Proves the PID 1 signal trap: a container whose PID 1
# ignores SIGTERM waits the full grace period and is SIGKILLed (exit 137), while
# one with --init (tini) forwards the signal and stops at once with a clean
# SIGTERM (exit 143). Throwaway containers, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/congrazia.sh" "$WORK"
a_ms=$(val "$WORK/stop.txt" a_ms)
a_code=$(val "$WORK/stop.txt" a_code)
b_ms=$(val "$WORK/stop.txt" b_ms)
b_code=$(val "$WORK/stop.txt" b_code)
grace_ms=$(val "$WORK/stop.txt" grace_ms)

# 1. container A ignores SIGTERM: it waits (almost) the full grace, then is SIGKILLed
if [ "$a_ms" -lt $(( grace_ms * 7 / 10 )) ] || [ "$a_code" != "137" ]; then
  echo "UNEXPECTED: A did not wait the grace and get SIGKILLed (${a_ms}ms, exit $a_code)" >&2; exit 1
fi
echo "OK 1 - A ignores SIGTERM: it waits the grace (${a_ms}ms) and is SIGKILLed (exit 137)"

# 2. container B (--init) forwards SIGTERM and stops at once, with a clean SIGTERM
if [ "$b_ms" -gt $(( grace_ms / 2 )) ] || [ "$b_code" != "143" ]; then
  echo "UNEXPECTED: B did not stop promptly with SIGTERM (${b_ms}ms, exit $b_code)" >&2; exit 1
fi
echo "OK 2 - B with --init stops at once (${b_ms}ms) with a clean SIGTERM (exit 143)"

# 3. the difference is the PID 1 that handles the signal: A is far slower than B
if [ "$a_ms" -le $(( b_ms * 3 )) ]; then
  echo "UNEXPECTED: A was not clearly slower than B (${a_ms}ms vs ${b_ms}ms)" >&2; exit 1
fi
echo "OK 3 - the gap is PID 1: A (${a_ms}ms) is far slower than B (${b_ms}ms) - --init makes the difference"

echo
echo "ALL CHECKS PASSED"
