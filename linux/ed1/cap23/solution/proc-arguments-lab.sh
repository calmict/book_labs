#!/usr/bin/env bash
set -euo pipefail

container_name=labcap23-proc
image_name=${LABCAP23_IMAGE:-alpine:3.20}
runtime=

cleanup() {
    if [[ -n "$runtime" ]]; then
        "$runtime" rm -f "$container_name" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

if command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    runtime=podman
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    runtime=docker
else
    printf 'SKIP: no usable Podman or Docker runtime is available.\n' >&2
    exit 77
fi

# shellcheck disable=SC2016  # single quotes on purpose: the string is expanded by the shell that receives it
output=$(
    "$runtime" run --rm --name "$container_name" "$image_name" sh -ceu '
        adduser -D labcap23owner
        adduser -D labcap23observer
        su labcap23owner -s /bin/sh -c "sh -c '\''while :; do sleep 1; done'\'' labcap23-demo-secret & echo \$!" > /tmp/labcap23-pid
        process_pid=$(cat /tmp/labcap23-pid)
        for attempt in 1 2 3 4 5; do
            test -r "/proc/$process_pid/cmdline" && break
            sleep 1
        done
        su labcap23observer -s /bin/sh -c "tr '\''\\000'\'' '\'' '\'' < /proc/$process_pid/cmdline"
        kill "$process_pid"
        wait "$process_pid" 2>/dev/null || true
    '
)
printf 'Second user read from cmdline: %s\n' "$output"
if [[ "$output" != *labcap23-demo-secret* ]]; then
    printf 'The expected argument was not visible.\n' >&2
    exit 1
fi
printf 'Argument visibility check passed.\n'
