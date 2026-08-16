# Chapter 6 — Enter a System Through the Service Door

> Exercise for **Chapter 6 — The Bootloader and the Handoff** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- read and preserve the running kernel command line;
- edit a GRUB entry temporarily without changing its on-disk configuration;
- compare a quiet boot with one that exposes kernel messages;
- reach rescue mode and start /bin/bash as PID 1;
- explain why access to the boot console often amounts to control of the system.

## Prerequisites

- An x86_64 Linux host where the current user can read and write the KVM device.
- qemu-system-x86_64 or qemu-kvm, qemu-img, timeout, Python 3, and pexpect.
- Your own Rocky Linux- or RHEL-compatible qcow2 base image, not used by another
  virtual machine. Set its path before starting the lab:

       export LABCAP06_BASE_IMAGE=/path/to/lab-image.qcow2

  The script never attaches the image directly to the virtual machine: each boot
  uses a fresh temporary overlay and keeps the base read-only.
- The GRUB menu must be available on both the serial and local consoles, with a
  timeout of at least 10 seconds. Some Debian and Ubuntu cloud images already
  provide serial output; Rocky Linux, RHEL, and Fedora images generally require
  explicit configuration. These /etc/default/grub lines are an example:

       GRUB_TERMINAL="serial console"
       GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"
       GRUB_TIMEOUT=15
       GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8 no_timer_check net.ifnames=0 crashkernel=auto"

  After changing the file, regenerate grub.cfg with the command required by the
  distribution and manually confirm that the menu appears on ttyS0 at 115200 baud.
- About 1 GiB of free memory and temporary space under /tmp.
- No other virtual machine or disk may be opened, modified, or stopped.

## Instructions

1. Preserve the host command line in the observation sheet:

       cat /proc/cmdline

   This is a read-only command. Copy its output to start/observations.md and
   identify root=, ro or rw, quiet, and init= when present.

2. Read the scripts before running them:

       sed -n '1,260p' solution/vm-lab.sh
       sed -n '1,320p' solution/vm-driver.py

   Confirm that the only attached disk is an overlay under /tmp, the network uses
   user mode, and the CPU, memory, console, timeout, and -no-reboot settings match
   the stated limits.

3. Run the lab and preserve its transcript:

       solution/vm-lab.sh | tee /tmp/labcap06-session.log

   The solution creates a fresh disposable overlay for each boot. Each boot is
   guarded by a 180-second timeout; a trap terminates any remaining qemu process
   and always removes the working directory.

4. During the first boot, the solution opens the selected GRUB entry, removes
   quiet from the linux line, and adds a harmless marker. Compare the transcript
   with a quiet boot: the kernel command line and initialization messages must
   appear before the login prompt.

5. During the second boot, it adds systemd.unit=rescue.target. Record the message
   that identifies rescue mode. Authentication is not required: reaching the
   maintenance prompt is the evidence requested here.

6. During the third boot, it adds init=/bin/bash. The shell prints /proc/cmdline
   and the state of PID 1; verify that process 1 runs /bin/bash. The solution then
   exits the emulator through the multiplexed console.

7. If the local GRUB entry layout differs from the expected layout, the script
   stops without reporting a successful test. Repeat that step manually: select
   the entry, press e, move to the line beginning with linux, remove only quiet,
   append the required parameter, and boot with Ctrl+X. The change applies to one
   boot and is not saved to disk.

8. Complete start/observations.md with transcript evidence and the final checks
   proving that qemu stopped and the overlay no longer exists.

## Definition of "done"

- [ ] You preserved and interpreted the current host command line.
- [ ] You observed a boot without quiet and the messages it previously hid.
- [ ] You reached the rescue-mode maintenance prompt.
- [ ] You verified /bin/bash as PID 1 after using init=/bin/bash.
- [ ] You edited GRUB only for the current boot and changed no boot configuration.
- [ ] You explained the risk associated with physical console access.
- [ ] The qemu process stopped and the directory containing the overlay is gone.
