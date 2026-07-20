#!/usr/bin/env bash
# cap03 solution - "the ceiling and the OOM": impose a cgroup memory limit and
# watch the OOM killer strike a process that exceeds it. Rootless: systemd-run
# --user --scope creates a transient cgroup in the user's delegated subtree (the
# systemd delegation of section 3.7), so no sudo and no Docker.
set -euo pipefail

OUT="${1:?usage: iltetto.sh OUTPUT_DIR}"
mkdir -p "$OUT"

# A memory ceiling of 40 MiB, with swap disabled so the limit truly bites.
CAP=(--user --scope -q -p MemoryMax=40M -p MemorySwapMax=0)
# The same scope without a ceiling, for the contrast.
NOCAP=(--user --scope -q -p MemoryMax=infinity)

greedy='x = bytearray(200 * 1024 * 1024)'   # asks for 200 MiB, far over the cap
frugal='x = bytearray(10 * 1024 * 1024)'    # asks for 10 MiB, well under the cap

rc() { "$@" >/dev/null 2>&1; echo $?; }     # run, swallow output, print exit code

# 1) greedy under the cap -> the OOM killer strikes -> exit 137 (128 + 9 = SIGKILL)
echo "greedy_capped_rc=$(rc systemd-run "${CAP[@]}" python3 -c "$greedy")"     >  "$OUT/mem.txt"
# 2) frugal under the same cap -> stays under the ceiling -> exit 0
echo "frugal_capped_rc=$(rc systemd-run "${CAP[@]}" python3 -c "$frugal")"     >> "$OUT/mem.txt"
# 3) greedy WITHOUT the cap -> the allocation itself is harmless -> exit 0
echo "greedy_uncapped_rc=$(rc systemd-run "${NOCAP[@]}" python3 -c "$greedy")" >> "$OUT/mem.txt"
