# Chapter 19 — The Data You Think You Saved

> Exercise for **Chapter 19 — Real Filesystems and the Block Layer** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- observe dirty data in the kernel cache after a write;
- measure the difference between finishing a write and requesting synchronization;
- replace a file without exposing intermediate states and make the new directory entry durable;
- trace the stack from a mount to its underlying block devices.

## Prerequisites

- A Linux host with Bash, Python 3, coreutils, util-linux, and procfs mounted.
- At least 200 MiB free in the exercise directory.
- No important data in solution/labcap19-work: the script recreates and removes it.
- No administrative privileges are needed, and no block device must be written directly.

## Instructions

1. Read the Dirty value in /proc/meminfo, write a regular file without requesting fsync, and immediately read the value again. Synchronize that file alone and observe Dirty once more. Remember that the counter covers the entire host and writeback may proceed while you measure it.

       awk '/^Dirty:/ {print}' /proc/meminfo
       dd if=/dev/zero of=buffered.bin bs=1M count=64 status=none
       awk '/^Dirty:/ {print}' /proc/meminfo
       sync buffered.bin
       awk '/^Dirty:/ {print}' /proc/meminfo

2. Time two equivalent writes to regular files in the exercise directory. The first finishes when the file is closed; the second uses conv=fsync to wait for synchronization. Repeat the measurements on a busy system, and do not treat one result as a storage-device benchmark.

       dd if=/dev/zero of=without-fsync.bin bs=1M count=64 status=none
       dd if=/dev/zero of=with-fsync.bin bs=1M count=64 conv=fsync status=none

3. Implement a function that also handles short writes: write the complete content to a temporary file in the same directory, call fsync on the file, close it, replace the final name with rename, and finally call fsync on the directory.

4. Keep a concurrent reader running through many replacements and validate every version it reads. The test must fail if it sees a missing, truncated, or mixed-version file.

5. Do not shut down the machine. Instead, exercise the synchronization path with a copy made by dd conv=fsync, then compare the source and persisted files byte for byte and by checksum. Explain that a real crash-recovery test requires a disposable virtual machine.

6. Use findmnt to identify the source and filesystem type of the working directory, then use lsblk to inspect disks, partitions, and parent relationships. Never write to those devices.

7. Record output and observations in answers.md, or run the solution:

       ./solution/run.sh

## Definition of "done"

- [ ] You collected Dirty before the write, immediately after it, and after synchronizing the file.
- [ ] You timed both writes and can distinguish write completion from persistence requested through fsync.
- [ ] The producer performs a complete write, file fsync, rename, and directory fsync, in that order.
- [ ] The concurrent reader sees no missing, partial, or mixed state.
- [ ] The conv=fsync copy passes cmp and produces matching checksums; no real crash was induced.
- [ ] You inspected the device stack with findmnt and lsblk without writing to a block device.
- [ ] All test files were removed at the end.

