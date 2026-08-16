# Chapter 6 — Observations (model solution)

## Host command line

The complete value comes from /proc/cmdline. root= identifies the initial root
device, ro asks for an initially read-only mount, quiet suppresses routine boot
messages, and init= replaces the first userspace program selected after the real
root is available. Parameters that are absent must not be inferred.

## Boot without quiet

The first guest transcript contains labcap06=verbose on the kernel command line
and does not contain quiet on that same line. Kernel and service initialization
messages appear before the login prompt. The edit exists for this boot only.

## Rescue mode

systemd.unit=rescue.target asks systemd to isolate the rescue target. Reaching the
maintenance or root-password prompt proves that the normal multi-user path was
replaced; entering a password is outside this exercise.

## Shell as PID 1

init=/bin/bash requests the shell instead of the normal first userspace process.
/proc/cmdline preserves that parameter, while ps reports PID 1 with /bin/bash as
its command. This path does not depend on the normal login service.

## Security conclusion

Anyone who can edit an unprotected boot entry may change the first userspace
program and bypass the ordinary login path. A bootloader password, locked firmware
settings, verified boot components, full-disk encryption, and controlled physical
access protect different parts of that path.

## Cleanup

The successful script ends with PASS for both the qemu-process check and overlay
removal. These checks are emitted by the EXIT trap after all three emulator runs.
