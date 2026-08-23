#!/usr/bin/env bash
# cap24 start - capabilities as least privilege, to complete. Six gaps (TODO 1..6):
# the three ping attempts, the mount that needs SYS_ADMIN, the syscall seccomp
# refuses on its own and what --privileged changes are missing, so the measurements
# are empty and the test fails. Throwaway containers (--rm), no host path mounted.
set -euo pipefail

OUT="${1:?usage: icapabilities.sh OUTPUT_DIR}"
mkdir -p "$OUT"

# TODO 1 (24.1): default capabilities - ping works (NET_RAW is granted):
#     default=$(docker run --rm busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')
default=""

# TODO 2 (24.1): all capabilities dropped - no NET_RAW, ping fails:
#     dropall=$(docker run --rm --cap-drop ALL busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')
dropall=""

# TODO 3 (24.1): all dropped, only NET_RAW granted back - ping works, least privilege:
#     dropadd=$(docker run --rm --cap-drop ALL --cap-add NET_RAW busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')
dropadd=""

# TODO 4 (24.1): a sharper capability. Mounting a filesystem needs SYS_ADMIN, which
#   the default set does not include: denied by default, allowed when granted back:
#     mount_default=$(docker run --rm busybox sh -c 'mkdir -p /mnt/t; mount -t tmpfs none /mnt/t >/dev/null 2>&1 && echo MOUNTED || echo DENIED')
#     mount_added=$(docker run --rm --cap-add SYS_ADMIN busybox sh -c 'mkdir -p /mnt/t; mount -t tmpfs none /mnt/t >/dev/null 2>&1 && echo MOUNTED || echo DENIED')
mount_default=""
mount_added=""

# TODO 5 (24.2): the second barrier. Read the seccomp mode, then try the same
#   syscall with and without the default profile - the capabilities do not change:
#     seccomp_mode=$(docker run --rm busybox sh -c 'grep "^Seccomp:" /proc/self/status | tr -d "\t" | cut -d: -f2')
#     unshare_default=$(docker run --rm busybox sh -c 'unshare -U true >/dev/null 2>&1 && echo ALLOWED || echo BLOCKED')
#     unshare_unconfined=$(docker run --rm --security-opt seccomp=unconfined busybox sh -c 'unshare -U true >/dev/null 2>&1 && echo ALLOWED || echo BLOCKED')
seccomp_mode=""
unshare_default=""
unshare_unconfined=""

# TODO 6 (24.4): --privileged removes both barriers at once. Read the effective
#   capability mask in the two cases and retry the mount. The container only reads
#   its own status and mounts a tmpfs inside itself: nothing on the host is touched:
#     caps_default=$(docker run --rm busybox sh -c 'grep "^CapEff:" /proc/self/status | tr -d "\t" | cut -d: -f2')
#     caps_privileged=$(docker run --rm --privileged busybox sh -c 'grep "^CapEff:" /proc/self/status | tr -d "\t" | cut -d: -f2')
#     mount_privileged=$(docker run --rm --privileged busybox sh -c 'mkdir -p /mnt/t; mount -t tmpfs none /mnt/t >/dev/null 2>&1 && echo MOUNTED || echo DENIED')
caps_default=""
caps_privileged=""
mount_privileged=""

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
