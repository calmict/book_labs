#!/usr/bin/env bash
# Chapter 5 solution - trace the runtime chain, query containerd and inspect its
# bundle through a read-only helper when needed, then run a rootless runc bundle.
set -euo pipefail

OUT=${1:?usage: runtime-lab.sh OUTPUT_DIR}
CONTAINER=${CAP05_CONTAINER:-lab-cap05}
HELPER=${CAP05_HELPER_IMAGE:-docker:29-dind}
mkdir -p "$OUT"

docker rm -f "$CONTAINER" "$CONTAINER-exp" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" alpine:3 sleep infinity >/dev/null
cleanup() { docker rm -f "$CONTAINER" "$CONTAINER-exp" >/dev/null 2>&1 || true; }
trap cleanup EXIT

pid=$(docker inspect --format '{{.State.Pid}}' "$CONTAINER")
p=$pid
: > "$OUT/parent-chain.txt"
while [ "$p" -ne 1 ]; do
  comm=$(ps -o comm= -p "$p")
  printf '%s:%s\n' "$p" "$comm" >> "$OUT/parent-chain.txt"
  p=$(awk '{print $4}' "/proc/$p/stat")
done

id=$(docker inspect --format '{{.Id}}' "$CONTAINER")
printf '%s\n' "$id" > "$OUT/container-id.txt"
if ctr --namespace moby task ls >/dev/null 2>&1 && [ -r "/run/containerd/io.containerd.runtime.v2.task/moby/$id/config.json" ]; then
  ctr --namespace moby task ls > "$OUT/containerd-task.txt"
  cp "/run/containerd/io.containerd.runtime.v2.task/moby/$id/config.json" "$OUT/config.json"
else
  docker run --rm \
    -v /run/containerd/containerd.sock:/run/containerd/containerd.sock \
    "$HELPER" ctr --namespace moby task ls > "$OUT/containerd-task.txt"
  docker run --rm \
    -v /run/containerd/io.containerd.runtime.v2.task/moby:/host/tasks:ro \
    "$HELPER" cat "/host/tasks/$id/config.json" > "$OUT/config.json"
fi

bundle="$OUT/bundle"
mkdir -p "$bundle/rootfs" "$bundle/state"
docker create --name "$CONTAINER-exp" alpine:3 >/dev/null
docker export "$CONTAINER-exp" | tar -x -C "$bundle/rootfs"
docker rm "$CONTAINER-exp" >/dev/null
(
  cd "$bundle"
  runc spec --rootless
  # shellcheck disable=SC2016  # expansions belong to the process inside runc
  sed -i 's/"sh"/"sh", "-c", "echo runc_pid=$$; echo runc_hostname=$(hostname)"/' config.json
  sed -i 's/"terminal": true/"terminal": false/' config.json
  if [ "${CAP05_DEFAULT_PROCESS:-0}" = 1 ]; then
    # shellcheck disable=SC2016  # match the literal command written above
    sed -i 's/"sh", "-c", "echo runc_pid=\$\$; echo runc_hostname=\$(hostname)"/"sh"/' config.json
  fi
  runc --root "$bundle/state" run demo
) > "$OUT/runc.txt"
