# Chapter 7 — Open the Borrowed Toolbox

> Exercise for **Chapter 7 — The Kernel Takes Control** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- distinguish dracut modules from kernel modules stored in an initramfs;
- identify the drivers selected to reach the root disk and filesystem;
- find the hooks or units that prepare /sysroot and hand off to the real root;
- demonstrate in a VM why a missing storage driver prevents booting;
- rebuild a working initramfs without knowing the guest password.

## Prerequisites

### Part 1 — Host, read-only

- A Linux host that uses dracut and lets the current user read
  /boot/initramfs-$(uname -r).img.
- The lsinitrd command. Rocky Linux, RHEL, and Fedora provide it in the dracut
  package, which is normally installed by default. Check before continuing:

       command -v lsinitrd
       command -v dracut

  If it is missing, install the dracut package with your distribution's package
  manager. Installation is a separate administrative task, not part of the
  read-only inspection.

### Part 2 — Dedicated VM

- An x86_64 Linux host where the current user can read and write /dev/kvm.
- qemu-system-x86_64 or /usr/libexec/qemu-kvm, qemu-img, timeout, Python 3,
  and pexpect.
- Your own minimal Rocky Linux 9- or RHEL 9-compatible qcow2 base image, built
  as described in Appendix A and not used by another virtual machine. Set its
  path without editing the script:

       export LABCAP07_BASE_IMAGE=/path/to/lab-image.qcow2

- GRUB must display its menu on the serial console for at least 10 seconds. Use
  the serial-console configuration already validated in Chapter 6.
- In the expected image, root is an XFS filesystem on /dev/vda3 and QEMU attaches
  the disk through virtio. The script checks these facts before changing anything.
- About 1 GiB of free memory and enough temporary space under /tmp.

Part 1 does not start QEMU and never changes /boot. Part 2 changes only a temporary
overlay; the base image is used as a backing file and is never attached directly
to the VM.

## Instructions

### Part 1 — Inspect a copy of the real initramfs

1. Run the automated inspection and preserve its output:

       set -o pipefail
       solution/inspect-initramfs.sh | tee /tmp/labcap07-inspection.log

   The script performs the same operation as this sequence, with checks and
   cleanup for the temporary copy:

       cp "/boot/initramfs-$(uname -r).img" /tmp/labcap07-inspect.img
       lsinitrd /tmp/labcap07-inspect.img
       lsinitrd /tmp/labcap07-inspect.img | grep -i module

2. In start/observations.md, separate the two families shown by lsinitrd. Dracut
   modules such as rootfs-block and base are functional generator components;
   files whose names end in .ko, possibly with compression, are kernel modules.
   Record the drivers for the controller, disk, and root filesystem.

3. Compare the inventory with the hardware in use:

       findmnt -no SOURCE,FSTYPE /
       lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINTS
       lspci -k

   A host-only initramfs mainly contains the chain needed to reach that machine's
   root, plus its dependencies. It is not a second copy of every driver installed
   under /usr/lib/modules.

4. The script lists the real names under usr/lib/dracut/hooks and uses lsinitrd -f
   to display hooks whose names mention root, mount, devexists, pivot, or switch.
   On systemd-based dracut images it also displays initrd-switch-root.service.
   Identify the check that waits for the root device and the component that moves
   from /sysroot to the real root. Names vary between versions; do not assume that
   one particular 90-something file must exist.

### Part 2 — Break and repair a real boot in the VM

5. Read the scripts before running them:

       sed -n '1,280p' solution/vm-lab.sh
       sed -n '1,420p' solution/vm-driver.py

   Confirm one vCPU, 768 MiB of RAM, user-mode networking, -no-reboot, the
   multiplexed serial console, and a 180-second timeout. The only attached disk
   must be the overlay created under /tmp.

6. Start the lab and preserve its complete transcript:

       set -o pipefail
       solution/vm-lab.sh | tee /tmp/labcap07-session.log

7. During the break stage, the script opens the GRUB entry editor, recognizes
   the text GRUB version 2.06, and appends init=/bin/bash to the linux line. This
   starts a PID 1 shell without credentials. Before writing, the solution verifies
   /dev/vda3, virtio_blk in the healthy initramfs, and the overlay backing file.
   It remounts / and, when separate, /boot read-write; preserves a healthy copy
   inside the same overlay; reads dracut --help; and rebuilds the image without
   virtio_blk.

8. During the broken stage, the same overlay boots from the altered initramfs.
   Preserve the literal failure message printed by your dracut and verify that
   the dracut shell is reached, virtio_blk is not loaded, and /dev/vda is absent.

9. During the repair stage, the script uses the same overlay again. In the GRUB
   editor it temporarily replaces the initrd line with the healthy copy, appends
   init=/bin/bash to the linux line, and boots with Ctrl+X. From the real root it
   rebuilds the standard initramfs name without omissions and verifies that
   virtio_blk is back in the archive.

10. During the verify stage, the same overlay performs a final boot from the
    standard name. Reaching the login prompt and seeing the kernel associate
    virtio_blk with vda prove that the real root is reachable again. Finally, the
    trap stops any remaining QEMU process and removes the overlay and temporary
    directory.

## Definition of "done"

- [ ] You inspected a copy and never the original file in /boot.
- [ ] You distinguished dracut modules from kernel modules.
- [ ] You related the storage and filesystem drivers to the host root.
- [ ] You read at least one real hook and the switch-root mechanism.
- [ ] You broke only the overlay initramfs and observed the dracut shell.
- [ ] You preserved the guest's actual failure message.
- [ ] You repaired the image without a password and verified the final boot.
- [ ] The QEMU process and temporary directory no longer exist.

## Safety

Never run Part 2's destructive dracut commands on the host. Never point
LABCAP07_BASE_IMAGE at a disk attached to another VM. Stop if the overlay,
/dev/vda3, or healthy-initramfs check fails. Access to the GRUB editor can bypass
the ordinary login path; protect the console, firmware, bootloader, and disk
encryption according to your threat model.
