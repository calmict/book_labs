#!/usr/bin/env python3

import mmap

CGROUP_CURRENT = "/sys/fs/cgroup/memory.current"
GIB = 1024 * 1024 * 1024


def memory_current():
    with open(CGROUP_CURRENT, encoding="ascii") as handle:
        return int(handle.read().strip())


def virtual_size_kib():
    with open("/proc/self/status", encoding="ascii") as handle:
        for line in handle:
            if line.startswith("VmSize:"):
                return int(line.split()[1])
    raise RuntimeError("VmSize not found")


before_current = memory_current()
before_virtual = virtual_size_kib()
reservation = mmap.mmap(-1, GIB, access=mmap.ACCESS_WRITE)
after_current = memory_current()
after_virtual = virtual_size_kib()

print(f"VmSize before: {before_virtual} KiB")
print(f"VmSize after: {after_virtual} KiB")
print(f"VmSize increase: {after_virtual - before_virtual} KiB")
print(f"memory.current before: {before_current // 1024} KiB")
print(f"memory.current after: {after_current // 1024} KiB")
print(f"physical cgroup increase: {(after_current - before_current) // 1024} KiB")
reservation.close()
