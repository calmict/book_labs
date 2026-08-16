# Chapter 5 — Identify and Safeguard Your Boot Chain

> Exercise for **Chapter 5 — BIOS and UEFI: Two Ways to Start a Machine** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- distinguish a UEFI boot from a BIOS boot by inspecting the firmware interface;
- locate and explore the EFI System Partition without modifying it;
- read BootCurrent, BootOrder, and the BootNNNN entries printed by efibootmgr -v;
- create and verify a boot-chain backup without writing to NVRAM.

## Prerequisites

- A normally booted Linux host with Bash, findmnt, find, tar, and sha256sum.
- efibootmgr. If it is missing, install it with the distribution package manager,
  for example:

       sudo dnf install -y efibootmgr

- Read-only access to the EFI System Partition. sudo or an administrative session
  is often required even when the partition is already mounted.
- Enough free space for a copy of the boot files.

## Instructions

1. Determine how the machine was booted:

       ls /sys/firmware/efi
       if test -d /sys/firmware/efi; then echo UEFI; else echo BIOS; fi

   If the directory exists, the kernel received the UEFI interface. If it is
   absent, do not invent entries or partitions: record that UEFI-specific steps do
   not apply to this boot.

2. On a UEFI machine, locate the EFI System Partition and inspect its mount options:

       findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS /boot/efi

   Explore it read-only. Prefix the command with sudo if permissions require it:

       find /boot/efi -maxdepth 4 -printf '%y %P\n' | sort

   Identify vendor directories, loaders with the .efi extension, and the optional
   EFI/BOOT fallback path. Do not unmount or remount the partition.

3. Read NVRAM without modifying it:

       efibootmgr -v

   BootCurrent is the entry used for the current boot. BootOrder lists the order
   in which entries are tried. Each BootNNNN entry links an identifier to a device,
   partition, and loader path; an asterisk marks an active entry.

4. Run the solution with a destination directory:

       solution/run.sh "$HOME/boot-backups"

   The script reads the ESP and NVRAM, creates an archive containing the ESP copy,
   file listing, mount data, efibootmgr -v output, and SHA-256 checksums, then
   verifies the archive. The backup is the only persistent result; temporary
   working data is always removed.

5. Keep a second copy of the backup on storage separate from the machine and record
   its location in start/answers.md. A backup stored only on the disk it protects
   is not enough.

## Commands You Must NOT Run on a Machine in Use

The commands below are examples to recognize only. Do not run them during the lab;
they can delete an entry or change the machine's real boot order:

       sudo efibootmgr -b 0001 -B
       sudo efibootmgr -o 0001,0000
       sudo efibootmgr -n 0000

A selection with -b also belongs to a modifying operation when paired with an
action. This lab uses efibootmgr exclusively with -v.

## Definition of "done"

- [ ] You determined UEFI or BIOS from the presence of /sys/firmware/efi.
- [ ] On UEFI, you identified the ESP source, type, and mount options.
- [ ] You listed ESP loaders without unmounting, remounting, or writing to it.
- [ ] You interpreted BootCurrent, BootOrder, and at least one BootNNNN entry.
- [ ] You created a verified archive containing the ESP copy, metadata, and checksums.
- [ ] You planned a second copy on separate storage.
- [ ] You ran no efibootmgr command that writes to NVRAM.
