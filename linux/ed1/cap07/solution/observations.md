# Chapter 7 — Model observations

## Part 1 — Host initramfs

lsinitrd first reports dracut's functional modules and then the archive contents.
The kernel drivers are the files ending in .ko plus an optional compression
suffix. Their exact set belongs in the learner's transcript: a host-only image
selects the controller, block-device, filesystem, and dependency chain needed by
that host instead of copying the entire installed module tree.

findmnt, lsblk, and lspci -k connect those names to the live root path. A virtio
guest will commonly need virtio_pci and virtio_blk; a physical host may instead
need NVMe, AHCI, SCSI, RAID, or device-mapper support. The root filesystem driver,
such as xfs, ext4, or btrfs, is the final part of the chain.

## Root hooks and handoff

The answer must quote names from the inspected archive rather than assume a fixed
filename. A host-only dracut image may contain a generated devexists hook under
the initqueue, while systemd-based images use generated units to mount /sysroot.
initrd-switch-root.service then invokes the switch-root operation after the
initrd targets have completed. Older or differently configured images may expose
the work in mount or pre-mount hooks instead.

## Part 2 — Controlled failure

The script accepts the destructive operation only after it has proved that the
guest root is /dev/vda3, that the healthy archive contains virtio_blk, and that
QEMU is writing to a verified qcow2 overlay. It prints dracut's own help and uses
an option whose description explicitly concerns kernel drivers. On the supported
Rocky Linux 9 image this is --omit-drivers; -o/--omit refers to dracut modules and
must not be substituted merely because its short spelling looks plausible.

The next boot reaches the dracut shell because no virtio_blk driver can create
/dev/vda and therefore /dev/vda3 cannot be mounted at /sysroot. The literal
warning differs with the root specification and dracut release, so the transcript
is the source of truth.

## Repair and cleanup

Before breaking the standard archive, the first stage stores a healthy copy on
the overlay's boot filesystem. The repair boot selects that copy temporarily in
the GRUB editor and adds init=/bin/bash. Once the healthy early userspace has made
/dev/vda3 available, the PID 1 shell can mount / and /boot read-write and run
dracut without an omission. The final boot again uses the standard filename.

Reaching the login prompt and observing the virtio_blk message for vda prove that
the real root path works again. The EXIT trap terminates any remaining emulator
and removes the one persistent overlay, so both the failure and repair disappear
without changing the base image.
