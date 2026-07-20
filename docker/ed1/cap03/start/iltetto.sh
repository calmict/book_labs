#!/usr/bin/env bash
# cap03 start - impose a cgroup memory ceiling and watch the OOM killer strike.
# Rootless via systemd-run --user (the systemd delegation of section 3.7): no
# sudo, no Docker. Three gaps to fill (TODO 1..3). As written the ceiling is
# missing, so nothing is ever OOM-killed.
set -euo pipefail

OUT="${1:?usage: iltetto.sh OUTPUT_DIR}"
mkdir -p "$OUT"

# TODO 1 (3.4): give the scope a memory ceiling. Complete the CAP array with a
#   40 MiB limit and swap disabled so the limit truly bites:
#     -p MemoryMax=40M -p MemorySwapMax=0
CAP=(--user --scope -q)
NOCAP=(--user --scope -q -p MemoryMax=infinity)

greedy='x = bytearray(200 * 1024 * 1024)'   # asks for 200 MiB, far over the cap
frugal='x = bytearray(10 * 1024 * 1024)'    # asks for 10 MiB, well under the cap

rc() { "$@" >/dev/null 2>&1; echo $?; }

# TODO 2 (3.5): run the greedy allocator UNDER the cap and record its exit code.
#   When it exceeds memory.max the OOM killer sends SIGKILL, so the code is 137
#   (128 + 9). Write:  greedy_capped_rc=<exit code>  to "$OUT/mem.txt".
: > "$OUT/mem.txt"

echo "frugal_capped_rc=$(rc systemd-run "${CAP[@]}" python3 -c "$frugal")"     >> "$OUT/mem.txt"

# TODO 3 (3.4): the contrast - run the SAME greedy allocator WITHOUT a cap (the
#   NOCAP scope) and record its exit code as greedy_uncapped_rc. It should be 0:
#   the allocation is harmless; the cap is what kills.
