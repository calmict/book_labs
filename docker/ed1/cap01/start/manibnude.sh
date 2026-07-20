#!/usr/bin/env bash
# cap01 start - build a "container" by hand with unshare, no Docker, and record
# proof that it is just a Linux process. Three gaps to fill (TODO 1..3). This
# start version is deliberately incomplete: as written it does NOT isolate.
set -euo pipefail

OUT="${1:?usage: manibnude.sh OUTPUT_DIR}"
mkdir -p "$OUT"

# TODO 3 (1.5): record the HOST's point of view, for the later comparison.
#   Write two lines to "$OUT/host.txt":
#     host_hostname=<the host hostname>
#     host_pidns=<readlink of /proc/self/ns/pid>
# (hint: a { ... } > "$OUT/host.txt" block with two echo lines)

# TODO 1 (1.4): add the flags that actually create the namespaces.
#   As written this only opens a USER namespace and forks - no isolation.
#   Add: --uts (isolated hostname), --pid --fork (new PID numbering, bash as
#   PID 1) and --mount-proc (so /proc reflects the new PID namespace).
unshare --user --map-root-user --fork \
  bash -c '
    # TODO 2 (1.4): prove the isolation from INSIDE.
    #   - set the hostname to nave-cargo
    #   - write to "$1/inside.txt" four lines:
    #       inside_hostname=<hostname>
    #       inside_pid=<$$>
    #       inside_proc_count=<count of ps -e lines>
    #       inside_pidns=<readlink of /proc/self/ns/pid>
    true
  ' bash "$OUT"
