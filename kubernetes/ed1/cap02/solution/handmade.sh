#!/usr/bin/env bash
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
{
  echo "host_hostname=$(hostname)"
  for ns in pid uts net user; do echo "host_${ns}ns=$(readlink /proc/self/ns/$ns)"; done
} > "$OUT/host.txt"

# The expressions in the single-quoted program expand in the inner shell.
# shellcheck disable=SC2016
unshare --user --map-root-user --pid --fork --mount --uts --ipc --net \
  chroot "$ROOTFS" /bin/sh -c '
    export PATH=/usr/sbin:/usr/bin:/sbin:/bin
    mount -t proc proc /proc
    hostname hand-made-container
    {
      echo "inside_pid=$$"
      echo "inside_hostname=$(hostname)"
      echo "inside_interfaces=$(awk -F: '\''NR > 2 {gsub(/ /, "", $1); printf "%s,", $1}'\'' /proc/net/dev)"
      for ns in pid uts net user; do echo "inside_${ns}ns=$(readlink /proc/self/ns/$ns)"; done
    }
  ' > "$OUT/inside.txt"
