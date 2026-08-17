#!/usr/bin/env python3

import os
import sys
import time


def cpu_load(seconds: float) -> None:
    deadline = time.monotonic() + seconds
    value = 0x12345678
    while time.monotonic() < deadline:
        value = (value * 1103515245 + 12345) & 0x7FFFFFFF
    print(f"cpu_checksum={value}")


def memory_load(mebibytes: int, hold_seconds: float) -> None:
    pages = []
    for _ in range(mebibytes):
        block = bytearray(1024 * 1024)
        for offset in range(0, len(block), 4096):
            block[offset] = 1
        pages.append(block)
    print(f"allocated_mib={mebibytes} pid={os.getpid()}", flush=True)
    time.sleep(hold_seconds)


if len(sys.argv) != 3:
    raise SystemExit("usage: workload.py cpu SECONDS | memory MEBIBYTES")

if sys.argv[1] == "cpu":
    cpu_load(float(sys.argv[2]))
elif sys.argv[1] == "memory":
    memory_load(int(sys.argv[2]), 1.0)
else:
    raise SystemExit(f"unknown workload: {sys.argv[1]}")
