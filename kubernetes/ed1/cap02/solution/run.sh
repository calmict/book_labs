#!/usr/bin/env bash
set -euo pipefail

# Chapter 2 solution — a container by hand, without Docker.
# Run as a normal user for the rootless variant (user namespace), or with
# sudo for the classic variant described in the brief.

ALPINE_URL=https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-minirootfs-3.24.1-x86_64.tar.gz

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/lab-cap02.XXXXXX")
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

ROOTFS=$WORKDIR/rootfs
mkdir -p "$ROOTFS"

echo "== Downloading the Alpine mini rootfs =="
if command -v curl >/dev/null 2>&1; then
  curl -fsSo "$WORKDIR/rootfs.tar.gz" "$ALPINE_URL"
else
  wget -qO "$WORKDIR/rootfs.tar.gz" "$ALPINE_URL"
fi
tar -xzf "$WORKDIR/rootfs.tar.gz" -C "$ROOTFS"

NSFLAGS=(--pid --fork --mount --uts --ipc --net)
if [ "$(id -u)" -ne 0 ]; then
  # Not root: the user namespace makes all the others possible (rootless).
  NSFLAGS=(--user --map-root-user "${NSFLAGS[@]}")
  echo "(running rootless: added --user --map-root-user)"
fi

echo
echo "== View from inside the hand-made container =="
# shellcheck disable=SC2016  # the $ expressions must expand in the inner shell
unshare "${NSFLAGS[@]}" chroot "$ROOTFS" /bin/sh -c '
  export PATH=/usr/sbin:/usr/bin:/sbin:/bin
  mount -t proc proc /proc
  hostname hand-made-container
  echo "--- id ---"
  id
  echo "--- hostname ---"
  hostname
  echo "--- ps aux ---"
  ps aux
  echo "--- ip addr ---"
  ip addr
  echo "--- namespaces of the container shell (my PID here is $$) ---"
  for ns in pid uts net user; do
    echo "$ns: $(readlink /proc/$$/ns/$ns)"
  done
'

echo
echo "== View from the host =="
echo "--- hostname ---"
hostname
echo "--- namespaces of the host shell ---"
for ns in pid uts net user; do
  echo "$ns: $(readlink "/proc/$$/ns/$ns")"
done
echo
echo "Compare the inode numbers in brackets: pid, uts and net always differ."
echo "user differs only in the rootless variant, where it is the namespace"
echo "that grants the privileges to create all the others."
