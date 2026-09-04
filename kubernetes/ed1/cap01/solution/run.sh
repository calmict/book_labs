#!/usr/bin/env bash
# cap01 - observes the same Linux process from the host and its container,
# checks PID, hostname and process-list isolation, then proves that removing
# PID isolation changes the result. Uses one disposable, unprivileged container.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { docker rm -f lab-cap01 lab-cap01-gate >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
value() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/observe.sh" "$WORK"
host_pid=$(value "$WORK/host.txt" host_pid)
inside_pid=$(value "$WORK/inside.txt" inside_pid)
host_name=$(value "$WORK/host.txt" host_hostname)
inside_name=$(value "$WORK/inside.txt" inside_hostname)
host_count=$(value "$WORK/host.txt" process_count)
inside_count=$(value "$WORK/inside.txt" process_count)

if [ "$inside_pid" != 1 ] || [ "$host_pid" -le 1 ]; then echo "UNEXPECTED: PID views are host=$host_pid inside=$inside_pid" >&2; exit 1; fi
echo "OK 1 - the same process is PID $host_pid on the host and PID 1 inside"
[ "$host_name" != "$inside_name" ] || { echo "UNEXPECTED: hostname was not isolated" >&2; exit 1; }
echo "OK 2 - the container hostname differs from the host hostname"
[ "$inside_count" -lt "$host_count" ] || { echo "UNEXPECTED: the container process list is not restricted" >&2; exit 1; }
echo "OK 3 - the container sees a restricted process list"

docker run -d --name lab-cap01-gate --pid=host alpine:3 sleep infinity >/dev/null
gate_pid=$(docker exec lab-cap01-gate sh -c 'echo $$')
[ "$gate_pid" -gt 1 ] || { echo "UNEXPECTED: host PID mode still reported PID 1" >&2; exit 1; }
echo "OK 4 - the gate bites: without PID isolation the process is not PID 1"
echo
echo "ALL CHECKS PASSED"
