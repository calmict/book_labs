# Setup — Linux exercises

## Recommended environment

A **virtual machine with snapshots**, running a recent distribution of the Debian
or Red Hat family. Not the most powerful machine: the one you can bring back
exactly to its starting point. You will observe processes, memory, filesystems,
networking, namespaces and cgroups, and for some chapters you will deliberately
break the boot.

Ask the machine what you actually have, instead of inferring it from the logo:

    cat /etc/os-release
    uname -a
    systemctl --failed        # the book assumes systemd

One VM for the whole volume: choose a Red Hat family distribution with SELinux
enabled. If you already work on Debian or Ubuntu, keep a second VM for chapter 23
alone — AppArmor is useful for its own section, but it does not replace the
exercise on contexts, types and restorecon.

    getenforce                # Enforcing is what chapter 23 needs

## Build a restorable baseline

Finish the installation and the updates, shut the VM down properly, then take the
snapshot **00-clean-base**. Save it with the VM powered off, so the baseline is
predictable. Before trusting it, actually test the restore:

    touch /var/tmp/snapshot-test && sync
    # shut down, restore 00-clean-base from the hypervisor, boot again
    ls -l /var/tmp/snapshot-test    # expected: it does not exist

If the file is still there you did not restore the point you thought you did.
Fix that before touching the boot. A snapshot is not a backup either: keep
outside the VM whatever you do not want to lose.

Take a fresh snapshot before each leap — **pre-ch05-07** before the boot labs,
**pre-ch23-selinux** before changing contexts or modes. Do not accumulate changes
from different chapters in one attempt: when something breaks you need to know
which variable you changed.

## The boot labs (chapters 5-7)

These exercises can stop the machine from booting. Run them on a **VM whose
snapshot you have already tested** — this is the lab requirement, not generic
caution. In the ESP do not delete files by hand and do not edit grub.cfg
directly; chapters 5 and 6 explain why.

For the UEFI labs, configure the virtual firmware in UEFI mode first and check
that the system really booted that way:

    test -d /sys/firmware/efi && echo UEFI
    efibootmgr -v
    findmnt /boot/efi

Before changing the UEFI boot order, check in your hypervisor's documentation
that the snapshot also covers the virtual firmware state (NVRAM). Not every
product treats the virtual disk and the NVRAM the same way; without that
guarantee, limit that attempt to reading the entries.

Commands come in distribution pairs — use the one for your family, never both:

    sudo update-grub            # Debian/Ubuntu
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg   # Red Hat/Fedora

    sudo update-initramfs -u    # Debian/Ubuntu
    sudo dracut --force         # Red Hat/Fedora

## Tools the volume uses

Several are not installed by default. Package names change between families, so
install the missing ones with your own package manager:

    for t in strace nft conntrack efibootmgr ausearch getcap setcap lsinitrd debootstrap; do
        command -v "$t" >/dev/null || echo "missing: $t"
    done

The mandatory access control tool is one of the two, not both — restorecon where
there is SELinux, aa-status where there is AppArmor:

    command -v restorecon || command -v aa-status

The isolation chapters (30-32) need cgroup v2, which is the default today:

    stat -fc %T /sys/fs/cgroup    # cgroup2fs = v2

## Break, observe, restore

Break one thing at a time and write down what you changed. If the boot fails,
first work out how far it got — firmware, bootloader, initramfs, kernel, PID 1 or
service — and collect the evidence *before* restoring, because going back to the
snapshot rewinds the journal too:

    dmesg -T --level=warn+
    journalctl -b
    journalctl -k -b -1       # previous boot, only if the journal is persistent
    systemd-analyze

If you never reach a shell, photograph the console, restore the snapshot and
repeat with a single change. The freedom to break things comes from a verified
return to a known state, not from the absence of mistakes.

## Running an exercise

    cd linux/ed1/capNN
    # complete the TODOs in start/ following README.it.md or README.en.md
    cd solution
    ./run.sh                  # prints OK 1.. and ALL CHECKS PASSED

Some labs need root for part of their checks; those steps are gated and the
brief says so. Run them in the VM, never on a machine you care about.
