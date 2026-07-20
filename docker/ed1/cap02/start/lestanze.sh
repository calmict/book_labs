#!/usr/bin/env bash
# cap02 start - build a process isolated in several namespaces at once and record
# proof of each room. No Docker, no sudo. Three gaps to fill (TODO 1..3). As
# written this only opens a USER namespace and isolates nothing else.
set -euo pipefail

OUT="${1:?usage: lestanze.sh OUTPUT_DIR}"
mkdir -p "$OUT"

# TODO 3 (2.1): record the HOST namespace inodes for the comparison. Write to
#   "$OUT/host.txt" one line per namespace:
#     host_uts=<readlink /proc/self/ns/uts>
#     host_pid=<readlink /proc/self/ns/pid>
#     host_mnt=<readlink /proc/self/ns/mnt>
#     host_net=<readlink /proc/self/ns/net>

# TODO 1 (2.2-2.5): add the flags that open one room each. As written unshare
#   only opens a USER namespace. Add: --uts (hostname), --pid --fork (PID 1),
#   --mount-proc, --mount (private mounts) and --net (a private network stack).
# shellcheck disable=SC2016
unshare --user --map-root-user --fork \
  bash -c '
    hostname sei-stanze
    # TODO 2 (2.4): prove the MNT namespace - mount a private tmpfs on /mnt and
    #   drop a marker file in it, so the test can confirm the host cannot see it:
    #     mount -t tmpfs tmpfs /mnt  &&  echo mounted > /mnt/marker
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
