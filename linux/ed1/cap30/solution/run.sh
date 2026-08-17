#!/usr/bin/env bash

set -Eeuo pipefail

scratch_dir=$(mktemp -d -t labcap30.XXXXXX)
launcher_pid=
shell_pid=
ready_file=$scratch_dir/ready
inside_file=$scratch_dir/inside

cleanup() {
    trap - EXIT INT TERM HUP
    if [[ -n ${launcher_pid:-} ]] && kill -0 "$launcher_pid" 2>/dev/null; then
        kill -KILL -- "-$launcher_pid" 2>/dev/null || true
        wait "$launcher_pid" 2>/dev/null || true
    fi
    find "$scratch_dir" -depth -delete 2>/dev/null || true
}

trap cleanup EXIT INT TERM HUP

for command_name in unshare nsenter ps mount timeout setsid; do
    command -v "$command_name" >/dev/null || {
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    }
done

host_uid=$(id -u)
host_hostname=$(hostname)
host_net_ns=$(readlink /proc/self/ns/net)

printf '%s\n' 'Starting the isolated shell'
setsid unshare --user --map-root-user --pid --net --uts --mount --propagation private --fork \
    /bin/sh -c '
        hostname labcap30-shell
        mount -t proc proc /proc
        {
            printf "inside_pid=%s\n" "$$"
            printf "inside_uid=%s\n" "$(id -u)"
            printf "inside_hostname=%s\n" "$(hostname)"
            printf "inside_net_ns=%s\n" "$(readlink /proc/self/ns/net)"
            printf "%s\n" "inside_interfaces:"
            awk -F: "NR > 2 { gsub(/ /, \"\", \$1); print \$1 }" /proc/net/dev
            printf "%s\n" "inside_uid_map:"
            cat /proc/self/uid_map
            printf "inside_process_count=%s\n" "$(ps -e --no-headers | wc -l)"
        } > "$1"
        : > "$2"
        exec sleep 20
    ' labcap30-inner "$inside_file" "$ready_file" &
launcher_pid=$!

for attempt in {1..50}; do
    [[ -e $ready_file ]] && break
    kill -0 "$launcher_pid" 2>/dev/null || {
        wait "$launcher_pid"
        exit 1
    }
    sleep 0.1
done

[[ -e $ready_file ]] || {
    printf '%s\n' 'The isolated shell did not become ready' >&2
    exit 1
}

shell_pid=$(ps -o pid= --ppid "$launcher_pid" | awk 'NR == 1 { print $1 }')
[[ $shell_pid =~ ^[0-9]+$ ]] || {
    printf '%s\n' 'Unable to find the isolated shell PID' >&2
    exit 1
}

cat "$inside_file"
printf 'host_pid=%s\n' "$shell_pid"
printf 'host_uid=%s\n' "$host_uid"
printf 'host_hostname=%s\n' "$host_hostname"
printf 'host_net_ns=%s\n' "$host_net_ns"
printf 'host_view_of_shell_uid=%s\n' "$(awk '/^Uid:/ { print $2 }' "/proc/$shell_pid/status")"

inside_pid=$(awk -F= '/^inside_pid=/ { print $2 }' "$inside_file")
inside_uid=$(awk -F= '/^inside_uid=/ { print $2 }' "$inside_file")
inside_hostname=$(awk -F= '/^inside_hostname=/ { print $2 }' "$inside_file")
inside_net_ns=$(awk -F= '/^inside_net_ns=/ { print $2 }' "$inside_file")

[[ $inside_pid == 1 ]]
[[ $inside_uid == 0 ]]
[[ $inside_hostname == labcap30-shell ]]
[[ $inside_net_ns != "$host_net_ns" ]]
[[ $(awk 'found { print $2; exit } /^inside_uid_map:/ { found=1 }' "$inside_file") == "$host_uid" ]]

printf '%s\n' 'Entering the namespaces from the host with nsenter'
timeout 5 nsenter --target "$shell_pid" --user --mount --uts --net --pid --preserve-credentials \
    /bin/sh -c '
        printf "nsenter_pid=%s\n" "$$"
        printf "nsenter_uid=%s\n" "$(id -u)"
        printf "nsenter_hostname=%s\n" "$(hostname)"
        printf "nsenter_net_ns=%s\n" "$(readlink /proc/self/ns/net)"
        printf "nsenter_process_count=%s\n" "$(ps -e --no-headers | wc -l)"
    '

printf '%s\n' 'All namespace checks passed; cleanup will now remove the isolated shell.'
