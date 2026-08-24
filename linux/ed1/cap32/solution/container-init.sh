#!/usr/bin/env bash

set -Eeuo pipefail

rootfs=$1
network_ready=$2

# shellcheck disable=SC2034  # the retry counter is deliberately unused: the loop only bounds the wait
for attempt in {1..100}; do
    [[ -e $network_ready ]] && break
    sleep 0.1
done
[[ -e $network_ready ]] || {
    printf '%s\n' 'Network setup did not complete.' >&2
    exit 1
}

mount --bind "$rootfs" "$rootfs"
mkdir -p "$rootfs/.oldroot"
cd "$rootfs"
pivot_root . .oldroot

mkdir -p /proc /dev/shm
mount -t proc proc /proc
mount -t tmpfs -o size=192m,nosuid,nodev tmpfs /dev/shm
umount -l /.oldroot
rmdir /.oldroot

hostname labcap32-container
ip link set lo up
ip link set labcap32-guest up
ip address add 10.200.32.2/24 dev labcap32-guest

exec /bin/sh /labcap32-tests.sh
