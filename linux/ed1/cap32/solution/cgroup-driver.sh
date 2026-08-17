#!/usr/bin/env bash

set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scope_relative=$(awk -F: '$1 == "0" { print $3 }' /proc/self/cgroup)
scope_dir=/sys/fs/cgroup$scope_relative
manager_dir=$scope_dir/labcap32-manager
container_dir=$scope_dir/labcap32-container
scratch_dir=$(mktemp -d -t labcap32.XXXXXX)
supervisor_pid=
sentinel_pid=

counter_value() {
    local file=$1
    local key=$2
    awk -v wanted="$key" '$1 == wanted { print $2 }' "$file"
}

cleanup() {
    trap - EXIT INT TERM HUP
    if [[ -n ${supervisor_pid:-} ]] && kill -0 "$supervisor_pid" 2>/dev/null; then
        kill -KILL -- "-$supervisor_pid" 2>/dev/null || true
        wait "$supervisor_pid" 2>/dev/null || true
    fi
    if [[ -n ${sentinel_pid:-} ]] && kill -0 "$sentinel_pid" 2>/dev/null; then
        kill -KILL "$sentinel_pid" 2>/dev/null || true
        wait "$sentinel_pid" 2>/dev/null || true
    fi
    if [[ -d $container_dir ]]; then
        [[ ! -w $container_dir/cgroup.kill ]] || printf '%s\n' 1 > "$container_dir/cgroup.kill" 2>/dev/null || true
        for attempt in {1..20}; do
            [[ -z $(<"$container_dir/cgroup.procs") ]] && break
            sleep 0.1
        done
        rmdir "$container_dir" 2>/dev/null || true
    fi
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
[[ $scope_relative == *labcap32-*scope ]] || {
    printf 'Refusing to run outside the delegated lab scope: %s\n' "$scope_relative" >&2
    exit 1
}
[[ -w $scope_dir/cgroup.subtree_control ]] || {
    printf '%s\n' 'The lab scope is not delegated.' >&2
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
mkdir "$container_dir"
printf '%s\n' '50000 100000' > "$container_dir/cpu.max"
printf '%s\n' $((96 * 1024 * 1024)) > "$container_dir/memory.max"
printf '%s\n' 1 > "$container_dir/memory.oom.group"
[[ ! -w $container_dir/memory.swap.max ]] || printf '%s\n' 0 > "$container_dir/memory.swap.max"

printf '%s\n' 'Building a minimal Debian root filesystem with debootstrap.'
mkdir -p "$scratch_dir/rootfs"
unshare --user --map-root-user --mount --propagation private --fork \
    debootstrap --variant=minbase --include=iproute2,iputils-ping,procps,coreutils \
    bookworm "$scratch_dir/rootfs" https://deb.debian.org/debian
install -m 0755 "$script_dir/container-tests.sh" "$scratch_dir/rootfs/labcap32-tests.sh"

bash -c 'exec -a labcap32-host-sentinel sleep 300' &
sentinel_pid=$!

cpu_before=$(counter_value "$container_dir/cpu.stat" nr_throttled)
oom_before=$(counter_value "$container_dir/memory.events" oom_kill)

setsid unshare --user --map-root-user --net --mount --propagation private --fork \
    "$script_dir/rootless-supervisor.sh" "$script_dir" "$scratch_dir" &
supervisor_pid=$!

for attempt in {1..2400}; do
    [[ -s $scratch_dir/wrapper.pid ]] && break
    kill -0 "$supervisor_pid" 2>/dev/null || {
        wait "$supervisor_pid"
        exit 1
    }
    sleep 0.1
done
[[ -s $scratch_dir/wrapper.pid ]] || {
    printf '%s\n' 'The root filesystem build did not finish in time.' >&2
    exit 1
}

container_wrapper=$(<"$scratch_dir/wrapper.pid")
[[ $container_wrapper =~ ^[0-9]+$ ]]
printf '%s\n' "$container_wrapper" > "$container_dir/cgroup.procs"
printf '%s\n' go > "$scratch_dir/release"

wait "$supervisor_pid"
supervisor_pid=

cpu_after=$(counter_value "$container_dir/cpu.stat" nr_throttled)
oom_after=$(counter_value "$container_dir/memory.events" oom_kill)
printf 'delegated_scope=%s\n' "$scope_relative"
printf 'cpu.max=%s\n' "$(<"$container_dir/cpu.max")"
printf 'nr_throttled=%s->%s\n' "$cpu_before" "$cpu_after"
printf 'memory.max=%s\n' "$(<"$container_dir/memory.max")"
printf 'oom_kill=%s->%s\n' "$oom_before" "$oom_after"
(( cpu_after > cpu_before ))
(( oom_after > oom_before ))
[[ -z $(<"$container_dir/cgroup.procs") ]]

printf '%s\n' 'All container defenses reacted as expected; cleanup will now remove the lab.'
