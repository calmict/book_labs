#!/usr/bin/env bash
# Complete TODO 1..3 to build and inspect a rootless container with Linux tools.
set -euo pipefail

OUT=${1:?usage: handmade.sh OUTPUT_DIR}
mkdir -p "$OUT"
ROOTFS=$OUT/rootfs
ARCHIVE=$OUT/rootfs.tar.gz
ALPINE_URL=https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-minirootfs-3.24.1-x86_64.tar.gz
mkdir -p "$ROOTFS"
if command -v curl >/dev/null 2>&1; then
  curl -fsSo "$ARCHIVE" "$ALPINE_URL"
else
  wget -qO "$ARCHIVE" "$ALPINE_URL"
fi
tar -xzf "$ARCHIVE" -C "$ROOTFS"
mkdir -p "$ROOTFS/proc"

# TODO 3 (2.5): record the host hostname and pid, uts, net and user namespace
# inodes in host.txt so they can be compared with the isolated process.

# TODO 1 (2.2, 2.3): add PID, mount, UTS, IPC and network isolation, then
# mount a private proc filesystem inside the chroot.
# Keep the USER namespace: it supplies safe root only inside the new namespaces.
unshare --user --map-root-user --fork \
  chroot "$ROOTFS" /bin/sh -c '
    export PATH=/usr/sbin:/usr/bin:/sbin:/bin
    # TODO 2 (2.2, 2.4, 2.5): mount a private /proc, set the hostname to
    # hand-made-container and write PID, hostname, interface and namespace
    # inode evidence to standard output; redirect it to inside.txt outside.
    true
  ' > "$OUT/inside.txt"
