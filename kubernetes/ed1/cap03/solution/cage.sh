#!/usr/bin/env bash
set -euo pipefail

UID_NOW=$(id -u)
CG_BASE=/sys/fs/cgroup/user.slice/user-${UID_NOW}.slice/user@${UID_NOW}.service
LAB_CG=$CG_BASE/lab-cap03-$$
trap 'rmdir "$LAB_CG" 2>/dev/null || true; systemctl --user reset-failed "lab-cap03-*.scope" 2>/dev/null || true' EXIT

mkdir "$LAB_CG"
controllers=$(cat "$LAB_CG/cgroup.controllers")
grep -qw memory <<< "$controllers"
grep -qw pids <<< "$controllers"
echo "delegated controllers: $controllers"

echo "CPU throttling requires cpu.max = 20000 100000, but cpu is not delegated to this user slice"

set +e
systemd-run --user --scope -q --collect \
  --unit=lab-cap03-memory-demo-$$.scope \
  -p MemoryMax=20M -p MemorySwapMax=0 \
  python3 -c "b=bytearray(200*1024*1024); print('ALLOCATED')"
memory_rc=$?
set -e
echo "limited allocation exit code: $memory_rc"

set +e
systemd-run --user --scope -q --collect \
  --unit=lab-cap03-pids-demo-$$.scope -p TasksMax=3 \
  bash -c 'for i in 1 2 3 4 5 6; do sleep 1 & done; wait'
pids_rc=$?
set -e
echo "limited fork exit code: $pids_rc"
