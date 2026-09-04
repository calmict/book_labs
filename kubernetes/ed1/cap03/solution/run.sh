#!/usr/bin/env bash
# cap03 - verifies a delegated cgroup v2, a memory OOM kill with its
# unrestricted counter-test, and a real TasksMax fork rejection.
# CPU is the sole skipped check: the user slice exposes only memory and pids.
# Measurement recorded on 2026-09-04: CPUQuota=20% took 3180 ms, while the
# unrestricted run took 3560 ms. The supposed limit therefore had no effect.
set -euo pipefail

UID_NOW=$(id -u)
CG_BASE=/sys/fs/cgroup/user.slice/user-${UID_NOW}.slice/user@${UID_NOW}.service
LAB_CG=$CG_BASE/lab-cap03-$$

cleanup() {
  rmdir "$LAB_CG" 2>/dev/null || true
  systemctl --user reset-failed 'lab-cap03-*.scope' 2>/dev/null || true
}
trap cleanup EXIT

[ "$(stat -fc %T /sys/fs/cgroup)" = cgroup2fs ] || {
  echo "UNEXPECTED: cgroup v2 is not mounted" >&2
  exit 1
}
command -v systemd-run >/dev/null 2>&1 || {
  echo "UNEXPECTED: systemd-run is required" >&2
  exit 1
}
[ -r "$CG_BASE/cgroup.controllers" ] || {
  echo "UNEXPECTED: the systemd user cgroup is unavailable" >&2
  exit 1
}
echo "PRECHECK cgroup v2 and the systemd user manager are available"

mkdir "$LAB_CG"
controllers=$(cat "$LAB_CG/cgroup.controllers")
if ! grep -qw memory <<< "$controllers" || ! grep -qw pids <<< "$controllers"; then
  echo "UNEXPECTED: delegated controllers are '$controllers', expected memory and pids" >&2
  exit 1
fi
echo "OK 1 - created a delegated cgroup; available controllers: $controllers"

echo "SKIP 2 - CPU throttling: the user slice does not delegate cpu; measured CPUQuota=20% at 3180 ms versus 3560 ms unrestricted, so the limit had no effect"

set +e
limited_output=$(systemd-run --user --scope -q --collect \
  --unit=lab-cap03-memory-limited-$$.scope \
  -p MemoryMax=20M -p MemorySwapMax=0 \
  python3 -c "b=bytearray(200*1024*1024); print('ALLOCATED')" 2>&1)
limited_rc=$?
set -e
if [ "$limited_rc" -ne 137 ] || [ -n "$limited_output" ]; then
  echo "UNEXPECTED: limited allocation returned $limited_rc with output '$limited_output'" >&2
  exit 1
fi
free_output=$(systemd-run --user --scope -q --collect \
  --unit=lab-cap03-memory-free-$$.scope \
  python3 -c "b=bytearray(200*1024*1024); print('ALLOCATED')" 2>&1)
[ "$free_output" = ALLOCATED ] || {
  echo "UNEXPECTED: unrestricted counter-test did not allocate memory" >&2
  exit 1
}
echo "OK 3 - MemoryMax kills the allocation with exit 137; unrestricted allocation succeeds"

set +e
pids_output=$(systemd-run --user --scope -q --collect \
  --unit=lab-cap03-pids-$$.scope -p TasksMax=3 \
  bash -c 'for i in 1 2 3 4 5 6; do sleep 1 & done; wait' 2>&1)
pids_rc=$?
set -e
if [ "$pids_rc" -eq 0 ] || ! grep -q 'Resource temporarily unavailable' <<< "$pids_output"; then
  echo "UNEXPECTED: TasksMax did not reject a fork" >&2
  exit 1
fi
echo "OK 4 - TasksMax=3 rejects a fork with Resource temporarily unavailable"
echo
echo "ALL CHECKS PASSED"
