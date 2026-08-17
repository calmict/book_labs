#!/usr/bin/env bash
set -uo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
failure=0

run_part() {
    local label=$1
    local script_path=$2
    printf '\n%s\n' "$label"
    "$script_path"
    local status=$?
    if [[ $status -eq 77 ]]; then
        printf 'Result: not executed because the environment does not meet the prerequisites.\n'
    elif [[ $status -ne 0 ]]; then
        printf 'Result: failed with status %s.\n' "$status" >&2
        failure=1
    else
        printf 'Result: passed.\n'
    fi
}

run_part 'SELinux label and domain test' "$script_dir/selinux-lab.sh"
run_part 'Process argument visibility test' "$script_dir/proc-arguments-lab.sh"
exit "$failure"
