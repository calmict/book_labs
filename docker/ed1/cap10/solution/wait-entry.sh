#!/bin/sh
set -eu

host=${WAIT_HOST:-127.0.0.1}
port=${WAIT_PORT:-18080}
delay=${DEPENDENCY_DELAY:-2}
timeout=${WAIT_TIMEOUT:-6}

# Simulate a local dependency that becomes ready after a short delay.
( sleep "$delay"; nc -l -p "$port" >/dev/null 2>&1 ) &
listener_pid=$!
deadline=$(( $(date +%s) + timeout ))

until nc -z "$host" "$port" >/dev/null 2>&1; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "ERROR: dependency $host:$port was not ready within ${timeout}s" >&2
    kill "$listener_pid" >/dev/null 2>&1 || true
    wait "$listener_pid" 2>/dev/null || true
    exit 1
  fi
  sleep 0.1
done

wait "$listener_pid" 2>/dev/null || true
exec "$@"
