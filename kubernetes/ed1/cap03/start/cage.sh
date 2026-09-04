#!/usr/bin/env bash
# Complete TODO 1..3 to inspect a delegated cgroup and exercise the memory
# and process controllers through systemd user scopes.
set -euo pipefail

UID_NOW=$(id -u)
CG_BASE=/sys/fs/cgroup/user.slice/user-${UID_NOW}.slice/user@${UID_NOW}.service
LAB_CG=$CG_BASE/lab-cap03-$$
trap 'rmdir "$LAB_CG" 2>/dev/null || true' EXIT

mkdir "$LAB_CG"
# TODO 1 (3.1, 3.2): read cgroup.controllers from LAB_CG and verify that
# memory and pids are delegated; creating the directory created the cgroup.

# CPU step (3.3): CPUQuota is intentionally not run because cpu is absent
# from the delegated controller list. On a disposable root environment,
# cpu.max would contain 20000 100000 for a 20 percent quota.

# TODO 2 (3.3): use systemd-run --user --scope with MemoryMax=20M and
# MemorySwapMax=0 to make a 200 MiB Python allocation receive SIGKILL.

# TODO 3 (3.3): use a systemd user scope with TasksMax=3 and attempt enough
# background sleeps to make bash report Resource temporarily unavailable.
