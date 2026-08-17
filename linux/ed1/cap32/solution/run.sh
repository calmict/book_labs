#!/usr/bin/env bash

set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
unit_name=labcap32-$$

for command_name in debootstrap ip nsenter pivot_root systemctl systemd-run timeout unshare; do
    command -v "$command_name" >/dev/null || {
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    }
done

if ! systemctl --user show-environment >/dev/null 2>&1; then
    printf '%s\n' 'LIVE TEST UNAVAILABLE: the systemd user bus cannot be reached in this environment.'
    printf '%s\n' 'No root filesystem, namespace, cgroup, interface, or workload was created.'
    exit 0
fi

exec systemd-run --user --scope --quiet --unit="$unit_name" \
    --property='Delegate=cpu memory pids' "$script_dir/cgroup-driver.sh"
