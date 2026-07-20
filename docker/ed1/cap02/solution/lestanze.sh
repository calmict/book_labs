#!/usr/bin/env bash
# cap02 solution - "the six rooms": build a process isolated in several namespaces
# at once (UTS, PID, MNT, NET, plus the USER namespace that lets it run rootless)
# and record proof of each isolation. No Docker, no sudo. The comparison metric is
# the inode of each namespace in /proc/<pid>/ns: same inode = same world, a
# different inode = a separate world.
set -euo pipefail

OUT="${1:?usage: lestanze.sh OUTPUT_DIR}"
mkdir -p "$OUT"

# The host's namespace inodes, for the later comparison.
{
  echo "host_uts=$(readlink /proc/self/ns/uts)"
  echo "host_pid=$(readlink /proc/self/ns/pid)"
  echo "host_mnt=$(readlink /proc/self/ns/mnt)"
  echo "host_net=$(readlink /proc/self/ns/net)"
} > "$OUT/host.txt"

# Build the isolated process. --user --map-root-user makes it rootless; the other
# flags open one room each: --uts (hostname), --pid --fork (PID 1), --mount
# (private mounts) and --net (a private, near-mute network stack).
# The child body is single-quoted on purpose: it must expand INSIDE the namespaces.
# shellcheck disable=SC2016
unshare --user --map-root-user --uts --pid --fork --mount-proc --mount --net \
  bash -c '
    hostname sei-stanze
    # A private mount, invisible to the host (MNT namespace).
    mount -t tmpfs tmpfs /mnt 2>/dev/null && echo mounted > /mnt/marker
    {
      echo "inside_hostname=$(hostname)"
      echo "inside_pid=$$"
      echo "inside_uts=$(readlink /proc/self/ns/uts)"
      echo "inside_pid_ns=$(readlink /proc/self/ns/pid)"
      echo "inside_mnt=$(readlink /proc/self/ns/mnt)"
      echo "inside_net=$(readlink /proc/self/ns/net)"
      echo "inside_marker=$(cat /mnt/marker 2>/dev/null || echo none)"
      echo "inside_net_ifaces=$(ip -o link show 2>/dev/null | wc -l)"
      echo "inside_id=$(id -u)"
    } > "$1/inside.txt"
  ' bash "$OUT"
