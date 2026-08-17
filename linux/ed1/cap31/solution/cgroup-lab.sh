#!/usr/bin/env bash

set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scope_relative=$(awk -F: '$1 == "0" { print $3 }' /proc/self/cgroup)
scope_dir=/sys/fs/cgroup$scope_relative
manager_dir=$scope_dir/labcap31-manager
cpu_dir=$scope_dir/labcap31-cpu
high_dir=$scope_dir/labcap31-high
max_dir=$scope_dir/labcap31-max
scratch_dir=$(mktemp -d -t labcap31.XXXXXX)
active_worker_pid=

event_value() {
    local file=$1
    local key=$2
    awk -v wanted="$key" '$1 == wanted { print $2 }' "$file"
}

cleanup() {
    trap - EXIT INT TERM HUP
    if [[ -n ${active_worker_pid:-} ]] && kill -0 "$active_worker_pid" 2>/dev/null; then
        kill -KILL "$active_worker_pid" 2>/dev/null || true
        wait "$active_worker_pid" 2>/dev/null || true
    fi
    for group_dir in "$max_dir" "$high_dir" "$cpu_dir"; do
        if [[ -d $group_dir ]]; then
            rmdir "$group_dir" 2>/dev/null || true
        fi
    done
    if [[ -d $manager_dir ]]; then
        printf '%s\n' '-cpu -memory' > "$scope_dir/cgroup.subtree_control" 2>/dev/null || true
        printf '%s\n' "$$" > "$scope_dir/cgroup.procs" 2>/dev/null || true
        rmdir "$manager_dir" 2>/dev/null || true
    fi
    find "$scratch_dir" -depth -delete 2>/dev/null || true
}

trap cleanup EXIT INT TERM HUP

[[ $(stat -fc %T /sys/fs/cgroup) == cgroup2fs ]] || {
    printf '%s\n' 'This lab requires cgroup v2.' >&2
    exit 1
}

[[ $scope_relative == *labcap31-*scope ]] || {
    printf 'Refusing to run outside the delegated lab scope: %s\n' "$scope_relative" >&2
    exit 1
}

[[ -w $scope_dir/cgroup.subtree_control ]] || {
    printf 'The scope is not delegated: %s is not writable.\n' "$scope_dir" >&2
    exit 1
}

controllers=$(<"$scope_dir/cgroup.controllers")
[[ " $controllers " == *' cpu '* && " $controllers " == *' memory '* ]] || {
    printf 'SKIP: this scope only has "%s" delegated, missing cpu and/or memory.\n' "$controllers" >&2
    printf 'The scope correctly requested cpu, memory and pids (Delegate=cpu memory pids),\n' >&2
    printf 'but a controller can only reach a delegated scope if every slice above it in\n' >&2
    printf 'the cgroup tree has already enabled that controller in its own\n' >&2
    printf 'cgroup.subtree_control — and user.slice on this host has never enabled cpu.\n' >&2
    printf 'That file is owned by systemd (PID 1) and only root can change it, typically\n' >&2
    printf 'by setting DefaultCPUAccounting=yes in /etc/systemd/system.conf and\n' >&2
    printf 'reloading, or by an administrator writing "+cpu" to\n' >&2
    printf '/sys/fs/cgroup/user.slice/cgroup.subtree_control directly.\n' >&2
    printf 'No workload was created; nothing needs cleaning up.\n' >&2
    exit 0
}

mkdir "$manager_dir"
printf '%s\n' "$$" > "$manager_dir/cgroup.procs"
printf '%s\n' '+cpu +memory' > "$scope_dir/cgroup.subtree_control"
mkdir "$cpu_dir" "$high_dir" "$max_dir"

printf 'delegated_scope=%s\n' "$scope_relative"
printf 'enabled_controllers=%s\n' "$(<"$scope_dir/cgroup.subtree_control")"

run_in_group() {
    local target_dir=$1
    local label=$2
    shift 2
    local gate=$scratch_dir/$label.gate
    mkfifo "$gate"
    (
        read -r < "$gate"
        exec "$@"
    ) &
    local worker_pid=$!
    active_worker_pid=$worker_pid
    printf '%s\n' "$worker_pid" > "$target_dir/cgroup.procs"
    printf '%s\n' go > "$gate"
    local worker_status=0
    wait "$worker_pid" || worker_status=$?
    active_worker_pid=
    find "$gate" -delete 2>/dev/null || true
    return "$worker_status"
}

printf '%s\n' 'CPU test: quota 50000, period 100000, duration 3 seconds'
printf '%s\n' '50000 100000' > "$cpu_dir/cpu.max"
cpu_periods_before=$(event_value "$cpu_dir/cpu.stat" nr_periods)
cpu_throttled_before=$(event_value "$cpu_dir/cpu.stat" nr_throttled)
cpu_usec_before=$(event_value "$cpu_dir/cpu.stat" throttled_usec)
run_in_group "$cpu_dir" cpu timeout --signal=KILL 5 \
    python3 "$script_dir/workload.py" cpu 3
cpu_periods_after=$(event_value "$cpu_dir/cpu.stat" nr_periods)
cpu_throttled_after=$(event_value "$cpu_dir/cpu.stat" nr_throttled)
cpu_usec_after=$(event_value "$cpu_dir/cpu.stat" throttled_usec)
printf 'cpu.max=%s\n' "$(<"$cpu_dir/cpu.max")"
printf 'nr_periods=%s->%s\n' "$cpu_periods_before" "$cpu_periods_after"
printf 'nr_throttled=%s->%s\n' "$cpu_throttled_before" "$cpu_throttled_after"
printf 'throttled_usec=%s->%s\n' "$cpu_usec_before" "$cpu_usec_after"
(( cpu_throttled_after > cpu_throttled_before ))

memory_load_mib=72
printf '%s\n' 'memory.high test: high 32 MiB, max 96 MiB, load 72 MiB'
printf '%s\n' $((32 * 1024 * 1024)) > "$high_dir/memory.high"
printf '%s\n' $((96 * 1024 * 1024)) > "$high_dir/memory.max"
[[ ! -w $high_dir/memory.swap.max ]] || printf '%s\n' 0 > "$high_dir/memory.swap.max"
high_before=$(event_value "$high_dir/memory.events" high)
set +e
run_in_group "$high_dir" high timeout --signal=KILL 8 \
    python3 "$script_dir/workload.py" memory "$memory_load_mib"
high_status=$?
set -e
high_after=$(event_value "$high_dir/memory.events" high)
printf 'memory.high=%s memory.max=%s exit_status=%s\n' \
    "$(<"$high_dir/memory.high")" "$(<"$high_dir/memory.max")" "$high_status"
printf 'high_events=%s->%s\n' "$high_before" "$high_after"
[[ $high_status == 0 ]]
(( high_after > high_before ))

printf '%s\n' 'memory.max test: high disabled, max 48 MiB, same 72 MiB load'
printf '%s\n' max > "$max_dir/memory.high"
printf '%s\n' $((48 * 1024 * 1024)) > "$max_dir/memory.max"
printf '%s\n' 1 > "$max_dir/memory.oom.group"
[[ ! -w $max_dir/memory.swap.max ]] || printf '%s\n' 0 > "$max_dir/memory.swap.max"
oom_before=$(event_value "$max_dir/memory.events" oom_kill)
set +e
run_in_group "$max_dir" max timeout --signal=KILL 8 \
    python3 "$script_dir/workload.py" memory "$memory_load_mib"
max_status=$?
set -e
oom_after=$(event_value "$max_dir/memory.events" oom_kill)
printf 'memory.high=%s memory.max=%s exit_status=%s\n' \
    "$(<"$max_dir/memory.high")" "$(<"$max_dir/memory.max")" "$max_status"
printf 'oom_kill_events=%s->%s\n' "$oom_before" "$oom_after"
[[ $max_status != 0 ]]
(( oom_after > oom_before ))

printf '%s\n' 'All cgroup checks passed; delegated children will now be removed.'
