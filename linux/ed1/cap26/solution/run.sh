#!/usr/bin/env bash
set -Eeuo pipefail

namespace=labcap26
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
start_dir=$(cd -- "$script_dir/../start" && pwd)
work_dir=$(mktemp -d -t labcap26.XXXXXX)
pipe_job=
namespace_created=0

cleanup() {
    local status=$?
    trap - EXIT INT TERM
    if [[ -n "$pipe_job" ]]; then
        kill "$pipe_job" 2>/dev/null || true
        wait "$pipe_job" 2>/dev/null || true
    fi
    if (( namespace_created )); then
        ip netns del "$namespace" >/dev/null 2>&1 || true
    fi
    rm -rf -- "$work_dir"
    printf 'CLEANUP namespace=%s temporary_files=removed\n' "$namespace"
    exit "$status"
}
trap cleanup EXIT INT TERM

for command_name in python3 strace ip sysctl wc grep; do
    command -v "$command_name" >/dev/null || {
        printf 'ERROR missing command: %s\n' "$command_name" >&2
        exit 1
    }
done

printf 'STEP 1 hidden failure\n'
missing_file="$work_dir/labcap26-missing.conf"
trace_file="$work_dir/trace.log"
trace_errors="$work_dir/trace.err"
if python3 "$start_dir/silent_failure.py" "$missing_file"; then
    printf 'ERROR the failing program unexpectedly succeeded\n' >&2
    exit 1
fi
set +e
strace -f -e trace=openat -o "$trace_file" \
    python3 "$start_dir/silent_failure.py" "$missing_file" 2> "$trace_errors"
trace_status=$?
set -e
if grep -Fq 'Operation not permitted' "$trace_errors"; then
    printf 'SKIP strace check: ptrace is blocked by this execution environment\n'
else
    trace_line=$(grep -F "$missing_file" "$trace_file" | tail -n 1 || true)
    if [[ "$trace_line" != *'-1 ENOENT'* ]]; then
        cat "$trace_errors" >&2
        printf 'STRACE_STATUS=%s\n' "$trace_status" >&2
        printf 'ERROR ENOENT was not found in the trace\n' >&2
        exit 1
    fi
    printf 'TRACE %s\n' "$trace_line"
fi

printf 'STEP 2 stdio buffering\n'
buffered_file="$work_dir/buffered.out"
python3 "$start_dir/buffered_writer.py" | cat > "$buffered_file" &
pipe_job=$!
sleep 0.2
buffered_bytes=$(wc -c < "$buffered_file")
wait "$pipe_job"
pipe_job=

unbuffered_file="$work_dir/unbuffered.out"
python3 -u "$start_dir/buffered_writer.py" | cat > "$unbuffered_file" &
pipe_job=$!
sleep 0.2
unbuffered_bytes=$(wc -c < "$unbuffered_file")
wait "$pipe_job"
pipe_job=
printf 'BUFFERED_BYTES_DURING_SLEEP=%s\n' "$buffered_bytes"
printf 'UNBUFFERED_BYTES_DURING_SLEEP=%s\n' "$unbuffered_bytes"
if (( buffered_bytes != 0 || unbuffered_bytes == 0 )); then
    printf 'ERROR buffering behavior did not match the expected result\n' >&2
    exit 1
fi

printf 'STEP 3 namespaced sysctl\n'
if (( EUID != 0 )); then
    printf 'SKIP namespace check requires root; rerun this script with sudo\n'
    exit 0
fi
if ip netns list | awk '{print $1}' | grep -Fxq "$namespace"; then
    printf 'ERROR namespace %s already exists\n' "$namespace" >&2
    exit 1
fi
ip netns add "$namespace"
namespace_created=1
ip netns exec "$namespace" sysctl -w net.ipv4.ip_forward=0
value_zero=$(ip netns exec "$namespace" sysctl -n net.ipv4.ip_forward)
ip netns exec "$namespace" sysctl -w net.ipv4.ip_forward=1
value_one=$(ip netns exec "$namespace" sysctl -n net.ipv4.ip_forward)
printf 'SYSCTL_AFTER_ZERO=%s\n' "$value_zero"
printf 'SYSCTL_AFTER_ONE=%s\n' "$value_one"
if [[ "$value_zero" != 0 || "$value_one" != 1 ]]; then
    printf 'ERROR unexpected sysctl values\n' >&2
    exit 1
fi
printf 'PERSISTENCE_SAMPLE=%s/99-labcap26.conf not_installed\n' "$script_dir"
