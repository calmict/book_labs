#!/usr/bin/env bash
# cap03 - solution test. Imposes a cgroup memory ceiling and proves it bites: a
# greedy process that exceeds it is OOM-killed with exit 137 (the 128+9 SIGKILL
# signature you will meet again in chapter 26), a frugal one survives, and the
# gate is the cap itself - without it the very same greedy allocation is harmless.
# Rootless via systemd-run --user (the delegation of section 3.7): no sudo.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/iltetto.sh" "$WORK"
greedy_capped=$(val "$WORK/mem.txt" greedy_capped_rc)
frugal_capped=$(val "$WORK/mem.txt" frugal_capped_rc)
greedy_uncapped=$(val "$WORK/mem.txt" greedy_uncapped_rc)

# 1. the greedy process under the cap is OOM-killed: exit 137 (128 + 9, SIGKILL)
if [ "$greedy_capped" != "137" ]; then
  echo "UNEXPECTED: greedy under the cap exited $greedy_capped, not 137 (OOM/SIGKILL)" >&2
  exit 1
fi
echo "OK 1 - the greedy process exceeds memory.max and is OOM-killed (exit 137)"

# 2. the frugal process under the same cap survives
if [ "$frugal_capped" != "0" ]; then
  echo "UNEXPECTED: frugal under the cap exited $frugal_capped, not 0" >&2
  exit 1
fi
echo "OK 2 - a frugal process under the same ceiling survives (exit 0)"

# 3. the gate is the cap: without it the very same greedy allocation is harmless
if [ "$greedy_uncapped" != "0" ]; then
  echo "UNEXPECTED: greedy WITHOUT a cap exited $greedy_uncapped, not 0" >&2
  exit 1
fi
echo "OK 3 - remove the ceiling and the same allocation is harmless (exit 0): the cap is the killer"

echo
echo "ALL CHECKS PASSED"
