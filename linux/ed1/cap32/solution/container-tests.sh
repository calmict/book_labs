#!/bin/sh

set -eu

printf 'container_pid=%s\n' "$$"
printf 'container_hostname=%s\n' "$(hostname)"
printf 'container_root_old_visible=%s\n' "$(test -e /.oldroot && printf yes || printf no)"
printf 'container_processes:\n'
ps -eo pid,ppid,comm

# shellcheck disable=SC2009  # ps and grep are the point here: the exercise inspects the listing itself
if ps -eo args | grep -q '[l]abcap32-host-sentinel'; then
    printf '%s\n' 'host_process_visible=yes'
    exit 1
fi
printf '%s\n' 'host_process_visible=no'

printf '%s\n' 'container_network:'
ip -brief address
ping -c 1 -W 2 10.200.32.1

printf '%s\n' 'cpu_break_test=starting_3_seconds'
set +e
timeout --signal=KILL 3 sh -c 'while :; do :; done'
cpu_status=$?
set -e
printf 'cpu_break_test=completed_with_status_%s\n' "$cpu_status"
test "$cpu_status" -eq 124 -o "$cpu_status" -eq 137

printf '%s\n' 'memory_break_test=writing_160_MiB_to_tmpfs'
timeout --signal=KILL 8 dd if=/dev/zero of=/dev/shm/labcap32-fill \
    bs=1M count=160 status=none
printf '%s\n' 'memory_break_test=unexpectedly_survived'
exit 1
