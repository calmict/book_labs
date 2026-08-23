#!/usr/bin/env bash
# cap24 solution - "the right keys, not all of them": capabilities as least
# privilege. The same operation - a ping, which needs the NET_RAW capability for its
# raw socket - is tried with three capability sets: the default set (works), all
# dropped (fails, even as root), and all dropped with only NET_RAW granted back
# (works). Then it repeats the exercise on a sharper capability, SYS_ADMIN, which
# mounting a filesystem needs; it shows that seccomp is a second, independent
# barrier - the same syscall refused with the default profile and allowed without
# it, at identical capabilities; and it reads what --privileged changes. Throwaway
# containers (--rm), no restart, no privileges on the host: no host path is ever
# mounted into them.
set -euo pipefail

OUT="${1:?usage: icapabilities.sh OUTPUT_DIR}"
mkdir -p "$OUT"

# TODO 1 (24.1): default capabilities - ping works (NET_RAW is granted).
default=$(docker run --rm busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

# TODO 2 (24.1): all capabilities dropped - no NET_RAW, ping fails.
dropall=$(docker run --rm --cap-drop ALL busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

# TODO 3 (24.1): all dropped, only NET_RAW granted back - ping works, least privilege.
dropadd=$(docker run --rm --cap-drop ALL --cap-add NET_RAW busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')


# TODO 4 (24.1): a sharper capability. Mounting a filesystem needs SYS_ADMIN, which
# the default set does not include: denied by default, allowed when granted back.
mount_default=$(docker run --rm busybox sh -c 'mkdir -p /mnt/t; mount -t tmpfs none /mnt/t >/dev/null 2>&1 && echo MOUNTED || echo DENIED')
mount_added=$(docker run --rm --cap-add SYS_ADMIN busybox sh -c 'mkdir -p /mnt/t; mount -t tmpfs none /mnt/t >/dev/null 2>&1 && echo MOUNTED || echo DENIED')

# TODO 5 (24.2): the second barrier. Seccomp filters syscalls independently of the
# capabilities: with the SAME set, unshare(CLONE_NEWUSER) is refused by the default
# profile and allowed when the profile is off.
seccomp_mode=$(docker run --rm busybox sh -c 'grep "^Seccomp:" /proc/self/status | tr -d "\t" | cut -d: -f2')
unshare_default=$(docker run --rm busybox sh -c 'unshare -U true >/dev/null 2>&1 && echo ALLOWED || echo BLOCKED')
unshare_unconfined=$(docker run --rm --security-opt seccomp=unconfined busybox sh -c 'unshare -U true >/dev/null 2>&1 && echo ALLOWED || echo BLOCKED')

# TODO 6 (24.4): --privileged removes both barriers at once. The container only
# reads its own capability mask and mounts a tmpfs inside itself: no host path is
# mounted, nothing on the host is touched.
caps_default=$(docker run --rm busybox sh -c 'grep "^CapEff:" /proc/self/status | tr -d "\t" | cut -d: -f2')
caps_privileged=$(docker run --rm --privileged busybox sh -c 'grep "^CapEff:" /proc/self/status | tr -d "\t" | cut -d: -f2')
mount_privileged=$(docker run --rm --privileged busybox sh -c 'mkdir -p /mnt/t; mount -t tmpfs none /mnt/t >/dev/null 2>&1 && echo MOUNTED || echo DENIED')

{
  echo "default=$default"
  echo "dropall=$dropall"
  echo "dropadd=$dropadd"
  echo "mount_default=$mount_default"
  echo "mount_added=$mount_added"
  echo "seccomp_mode=$seccomp_mode"
  echo "unshare_default=$unshare_default"
  echo "unshare_unconfined=$unshare_unconfined"
  echo "caps_default=$caps_default"
  echo "caps_privileged=$caps_privileged"
  echo "mount_privileged=$mount_privileged"
} > "$OUT/caps.txt"
