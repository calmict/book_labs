#!/usr/bin/env bash
# cap01 solution - "the bare-hands container": build one with unshare, with no
# Docker at all, and record proof that it is just a Linux process wearing a mask:
# a new PID namespace (PID 1 inside), an isolated hostname (UTS), and a /proc
# that reflects the new world. Rootless (a USER namespace) so it needs no sudo.
set -euo pipefail

OUT="${1:?usage: manibnude.sh OUTPUT_DIR}"
mkdir -p "$OUT"

# The host's own point of view, captured first for the later comparison.
{
  echo "host_hostname=$(hostname)"
  echo "host_pidns=$(readlink /proc/self/ns/pid)"
} > "$OUT/host.txt"

# Build the container by hand. The flags, one by one:
#   --user --map-root-user : a USER namespace (the "fake root" of chapter 2) so
#                            this runs WITHOUT sudo.
#   --uts                  : an isolated hostname.
#   --pid --fork           : a new PID numbering; --fork makes bash become PID 1.
#   --mount-proc           : remount /proc so it reflects the new PID namespace.
# The child body is single-quoted on purpose: $$ and $1 must expand INSIDE the
# new namespaces, not here.
# shellcheck disable=SC2016
unshare --user --map-root-user --uts --pid --fork --mount-proc \
  bash -c '
    hostname nave-cargo
    {
      echo "inside_hostname=$(hostname)"
      echo "inside_pid=$$"
      echo "inside_proc_count=$(ps -e --no-headers 2>/dev/null | wc -l)"
      echo "inside_pidns=$(readlink /proc/self/ns/pid)"
    } > "$1/inside.txt"
  ' bash "$OUT"
