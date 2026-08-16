#!/usr/bin/env python3

import os

MIB = 1024 * 1024
blocks = []
allocated = 0

with open("/proc/self/oom_score_adj", "w", encoding="ascii") as score:
    score.write("500\n")

print(f"allocator pid: {os.getpid()}", flush=True)
print("oom_score_adj: 500", flush=True)
while True:
    block = bytearray(8 * MIB)
    for offset in range(0, len(block), 4096):
        block[offset] = 1
    blocks.append(block)
    allocated += 8
    print(f"touched allocation: {allocated} MiB", flush=True)
