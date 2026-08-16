# Chapter 6 — Observations

## Host command line

- Complete command line:
- Meaning of the relevant parameters:

## Boot without quiet

- Kernel command line shown by the guest:
- Initialization messages observed before login:

## Rescue mode

- Parameter added in GRUB:
- Serial-console evidence:

## Shell as PID 1

- Parameter added in GRUB:
- Output of /proc/cmdline:
- Output for PID 1:

## Security conclusion

- Why boot-console access can bypass the normal login path:
- Firmware, bootloader, disk-encryption, and physical-access controls that reduce the risk:

## Cleanup

- Qemu process check:
- Overlay removal check:
