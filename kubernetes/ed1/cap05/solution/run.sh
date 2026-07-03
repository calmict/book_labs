#!/usr/bin/env bash
set -euo pipefail

# Chapter 5 solution — climb the runtime chain, then run a container with
# runc alone. Root gets the full sequence (ctr + OCI bundle inspection);
# a regular user gets the chain and the rootless runc finale.

CONTAINER=lab-cap05
BUNDLE=$(mktemp -d "${TMPDIR:-/tmp}/lab-cap05.XXXXXX")

cleanup() {
  docker rm -f "$CONTAINER" "$CONTAINER-exp" >/dev/null 2>&1 || true
  rm -rf "$BUNDLE"
}
trap cleanup EXIT
cleanup

echo "== 1. The lab container =="
docker run -d --name "$CONTAINER" alpine:3 sleep infinity >/dev/null
PID=$(docker inspect --format '{{.State.Pid}}' "$CONTAINER")
echo "container process PID (host view): $PID"

echo
echo "== 2. The parent chain up to PID 1 =="
P=$PID
while [ "$P" -ne 1 ]; do
  ps -o pid=,comm= -p "$P"
  P=$(awk '{print $4}' "/proc/$P/stat")
done
echo "(the next parent is PID 1: neither dockerd nor containerd in the chain)"

echo
echo "== 3. The two big names run, but as bystanders =="
pgrep -l 'dockerd|containerd' || true

if [ "$(id -u)" -eq 0 ]; then
  echo
  echo "== 4. Talking to containerd directly (docker is just a client) =="
  ctr --namespace moby task ls

  echo
  echo "== 5. The OCI bundle containerd prepared for runc =="
  ID=$(docker inspect --format '{{.Id}}' "$CONTAINER")
  B="/run/containerd/io.containerd.runtime.v2.task/moby/$ID"
  ls "$B"
  echo "--- chapters 2-4, found again inside config.json ---"
  for section in namespaces resources capabilities; do
    if grep -q "\"$section\"" "$B/config.json"; then
      echo "found section: $section"
    fi
  done
else
  echo
  echo "(not root: skipping the ctr and OCI-bundle steps — rerun with sudo to see them)"
fi

echo
echo "== 6. The grand finale: runc alone, no daemons =="
mkdir -p "$BUNDLE/rootfs"
docker create --name "$CONTAINER-exp" alpine:3 >/dev/null
docker export "$CONTAINER-exp" | tar -x -C "$BUNDLE/rootfs"
docker rm "$CONTAINER-exp" >/dev/null
cd "$BUNDLE" || exit 1
if [ "$(id -u)" -eq 0 ]; then
  runc spec
else
  runc spec --rootless
fi
# batch command instead of the brief's interactive shell
# shellcheck disable=SC2016  # $(hostname) must expand inside the container
sed -i 's/"sh"/"sh", "-c", "echo hello from runc: hostname=$(hostname); ps aux"/' config.json
sed -i 's/"terminal": true/"terminal": false/' config.json
runc --root "$BUNDLE/state" run demo
echo "(runc exited together with the container: one-shot executor, not a daemon)"
