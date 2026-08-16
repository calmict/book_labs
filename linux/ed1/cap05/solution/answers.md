# Chapter 5 — Answers (model solution)

## Firmware mode

/sys/firmware/efi present means the current kernel booted through UEFI. Its absence
means BIOS mode or an environment that does not expose the host firmware interface.
That observation concerns the current boot, not merely the disk's partition table.

## EFI System Partition

findmnt supplies the mount target, block source, FAT-family filesystem, and mount
options. Vendor directories under EFI contain boot loaders. EFI/BOOT contains the
architecture-specific fallback loader when one is installed. Exploring and
archiving these files requires reads only; no remount is needed.

## NVRAM boot entries

BootCurrent identifies the entry that started this session. BootOrder gives the
firmware's search sequence. A BootNNNN line describes a device path and usually a
loader path such as a file below EFI. The identifier connects that description to
BootCurrent and BootOrder; an asterisk marks an active entry.

## Backup

The generated archive contains an unmodified tar stream of the ESP plus the mount
record, complete file list, firmware mode, NVRAM listing, and SHA-256 checksums.
The script checks the inner tar stream, validates the checksums, and lists the
outer archive before publishing it. A usable recovery plan stores another copy on
independent media and records enough metadata to identify the correct ESP and
loader entries.
