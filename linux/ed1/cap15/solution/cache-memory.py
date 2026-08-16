#!/usr/bin/env python3

import os

CGROUP = "/sys/fs/cgroup"
FILE_PATH = "/data/labcap15-cache.bin"
MIB = 1024 * 1024


def read_number(name):
    with open(os.path.join(CGROUP, name), encoding="ascii") as handle:
        value = handle.read().strip()
    if value == "max":
        raise RuntimeError("this experiment requires a finite cgroup limit")
    return int(value)


def read_stat():
    result = {}
    with open(os.path.join(CGROUP, "memory.stat"), encoding="ascii") as handle:
        for line in handle:
            key, value = line.split()
            result[key] = int(value)
    return result


def snapshot(label):
    limit = read_number("memory.max")
    current = read_number("memory.current")
    stats = read_stat()
    file_cache = stats.get("file", 0)
    free = max(0, limit - current)
    available = min(limit, free + file_cache)
    print(label, flush=True)
    print(f"  memory.max: {limit // MIB} MiB", flush=True)
    print(f"  memory.current: {current // MIB} MiB", flush=True)
    print(f"  cgroup free: {free // MIB} MiB", flush=True)
    print(f"  file cache: {file_cache // MIB} MiB", flush=True)
    print(f"  cgroup available estimate: {available // MIB} MiB", flush=True)


snapshot("before filling the page cache")
chunk = bytes(MIB)
with open(FILE_PATH, "wb", buffering=0) as output:
    for _ in range(120):
        output.write(chunk)
    os.fsync(output.fileno())
snapshot("after writing and synchronizing 120 MiB")
