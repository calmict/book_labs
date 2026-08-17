# Verified observations

## Live process

The inspection process keeps an ordinary file descriptor open, allocates and touches memory, and remains alive until the runner sends SIGTERM. The fd directory exposes links to its open objects, status provides a concise process and memory summary, and smaps_rollup aggregates its mappings. Namespace entries are links whose targets contain a namespace type and inode.

## Zombie

The child exits immediately while the parent deliberately postpones waitpid. During that interval, ps and status report Z. SIGUSR1 tells the parent to call waitpid; after that call, the child PID is absent from /proc.

## FIFO wait

Opening a FIFO for reading when no writer exists sleeps interruptibly. The measured state is S, and SIGKILL terminates the process. This mechanism cannot create or verify state D. A claim that the FIFO process remained in D after SIGKILL would contradict the observed kernel state.

## dm-delay wait (optional, root)

A dm-delay target built on a loop-backed file, given a 5-second delay, produces a genuine uninterruptible wait: `ps` reports STAT `D` and `/proc/PID/status` reports `State: D (disk sleep)` for the duration, with `dmsetup status` showing a non-zero pending-operation counter during the wait. Unlike the FIFO wait above, this state is genuinely non-interruptible.

Three details matter for reproducing this correctly, each a real trap hit while building this lab, not a theoretical one:

1. `dmsetup create` normally blocks waiting for a udev acknowledgment that may never arrive even though the kernel has already created the mapping (`--noudevsync` avoids this without disabling anything the reader needs).
2. A plain buffered read can return instantly from the page cache without ever reaching the delay target (`iflag=direct` forces a real read through it).
3. The system's udev rules run `blkid` against every new device-mapper node and set a watch on it; against a delay target, blkid's own probe read costs the full delay too, and `dmsetup remove` refuses a device that is still open — the removal then fails with `Device or resource busy`, and no amount of retrying helps, because the device stays open for as long as udev's own rule processing is still running. A rule file scoped to this device's name only, installed in `/run/udev/rules.d/` (and removed at the end) before the device is created, tells udev to skip its disk rules and its watch entirely for this one device. The rule's filename prefix matters: it must sort between `10-dm.rules` (which sets the `DM_NAME` this rule matches on) and `13-dm-disk.rules` (which runs blkid) for udev to apply it in time — a later-sorting name loses the race and never takes effect.
