#!/usr/bin/env bash
# Chapter 5 start - trace a container through shim and containerd, inspect its
# OCI bundle, then invoke runc directly. Valid but incomplete; three gaps remain.
set -euo pipefail

OUT=${1:?usage: runtime-lab.sh OUTPUT_DIR}
CONTAINER=${CAP05_CONTAINER:-lab-cap05}
mkdir -p "$OUT"

docker rm -f "$CONTAINER" "$CONTAINER-exp" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" alpine:3 sleep infinity >/dev/null
trap 'docker rm -f "$CONTAINER" "$CONTAINER-exp" >/dev/null 2>&1 || true' EXIT

# TODO 1 (5.2): follow the fourth field of /proc/PID/stat up to PID 1 and write
# pid:comm records to parent-chain.txt. This proves which process stays between
# the workload and init after runc has exited.
: > "$OUT/parent-chain.txt"

# TODO 2 (5.1, 5.3): query containerd's moby namespace and read the task's
# config.json. If direct access is denied, use a non-privileged docker:29-dind
# helper with the socket mounted and the task directory mounted read-only.
: > "$OUT/containerd-task.txt"
: > "$OUT/config.json"

# TODO 3 (5.3): export a rootfs, generate a rootless runc spec, replace the
# default interactive process with a batch command that records PID 1, and run
# the bundle with runc alone. Store its output in runc.txt.
: > "$OUT/runc.txt"
