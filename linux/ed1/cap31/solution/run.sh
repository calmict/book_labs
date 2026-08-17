#!/usr/bin/env bash

set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
unit_name=labcap31-$$

for command_name in systemctl systemd-run python3 timeout; do
    command -v "$command_name" >/dev/null || {
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    }
done

if ! systemctl --user show-environment >/dev/null 2>&1; then
    printf '%s\n' 'LIVE TEST UNAVAILABLE: the systemd user bus cannot be reached in this environment.'
    printf '%s\n' 'No cgroup or workload was created. Run this script from a login session with a user manager.'
    exit 0
fi

exec systemd-run --user --scope --quiet --unit="$unit_name" \
    --property='Delegate=cpu memory pids' "$script_dir/cgroup-lab.sh"
