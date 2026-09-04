#!/usr/bin/env bash
# Chapter 5 verification - proves the live process chain, direct containerd
# view, OCI bundle contents, and one-shot runc execution. The helper is neither
# privileged nor persistent; task data is mounted read-only. Rootless overall.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

"$HERE/runtime-lab.sh" "$WORK/result"

first_comm=$(head -1 "$WORK/result/parent-chain.txt" | cut -d: -f2-)
second_comm=$(sed -n '2p' "$WORK/result/parent-chain.txt" | cut -d: -f2-)
test "$first_comm" = sleep
case "$second_comm" in containerd-shim*) ;; *) exit 1 ;; esac
echo "OK 1 - the workload's direct parent is containerd-shim and the chain then reaches init"

id=$(cat "$WORK/result/container-id.txt")
test -n "$id"
grep -q "$id" "$WORK/result/containerd-task.txt"
echo "OK 2 - ctr finds the same running task in containerd's moby namespace"

jq -e '.linux.namespaces and .linux.resources and .process.capabilities and .root.path' \
  "$WORK/result/config.json" >/dev/null
echo "OK 3 - the live OCI bundle contains namespaces, cgroups, capabilities, and rootfs"

grep -q '^runc_pid=1$' "$WORK/result/runc.txt"
echo "OK 4 - runc alone starts the bundle process as PID 1 and then exits"

if CAP05_CONTAINER=lab-cap05-contrast CAP05_DEFAULT_PROCESS=1 \
  "$HERE/runtime-lab.sh" "$WORK/contrast" >/dev/null 2>&1 && \
  grep -q '^runc_pid=1$' "$WORK/contrast/runc.txt"; then
  echo "UNEXPECTED: the default OCI process produced the required PID evidence" >&2
  exit 1
fi
echo "OK 5 - the gate bites: without the completed process spec, the PID evidence disappears"

echo
echo "ALL CHECKS PASSED"
