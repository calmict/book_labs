#!/usr/bin/env bash

set -Eeuo pipefail

script_dir=$1
scratch_dir=$2
rootfs=$scratch_dir/rootfs
wrapper_file=$scratch_dir/wrapper.pid
release_file=$scratch_dir/release
network_ready=$scratch_dir/network-ready
container_launcher=

cleanup() {
    trap - EXIT INT TERM HUP
    if [[ -n ${container_launcher:-} ]] && kill -0 "$container_launcher" 2>/dev/null; then
        kill -KILL "$container_launcher" 2>/dev/null || true
        wait "$container_launcher" 2>/dev/null || true
    fi
    if ip link show labcap32-host >/dev/null 2>&1; then
        ip link delete labcap32-host 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM HUP

(
    for attempt in {1..600}; do
        [[ -e $release_file ]] && break
        sleep 0.1
    done
    [[ -e $release_file ]]
    exec unshare --user --map-root-user --pid --net --uts --mount --ipc \
        --propagation private --fork "$script_dir/container-init.sh" \
        "$rootfs" "$network_ready"
) &
container_launcher=$!
printf '%s\n' "$container_launcher" > "$wrapper_file"

# shellcheck disable=SC2034  # the retry counter is deliberately unused: the loop only bounds the wait
for attempt in {1..100}; do
    container_pid=$(ps -o pid= --ppid "$container_launcher" | awk 'NR == 1 { print $1 }')
    [[ $container_pid =~ ^[0-9]+$ ]] && break
    kill -0 "$container_launcher" 2>/dev/null || {
        wait "$container_launcher"
        exit 1
    }
    sleep 0.1
done
[[ ${container_pid:-} =~ ^[0-9]+$ ]] || {
    printf '%s\n' 'Unable to find the container process.' >&2
    exit 1
}

ip link add labcap32-host type veth peer name labcap32-guest netns "$container_pid"
ip address add 10.200.32.1/24 dev labcap32-host
ip link set labcap32-host up
printf '%s\n' ready > "$network_ready"

set +e
wait "$container_launcher"
container_status=$?
set -e
container_launcher=
printf 'container_exit_status=%s\n' "$container_status"
[[ $container_status != 0 ]]

if ip link show labcap32-host >/dev/null 2>&1; then
    ip link delete labcap32-host
fi
printf '%s\n' 'container_network_removed=yes'
