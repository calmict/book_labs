#!/usr/bin/env bash
# cap10 - solution test. Builds the ENTRYPOINT/CMD image and checks: running with
# no arguments, ENTRYPOINT runs with CMD's default arguments; run arguments
# override CMD but not ENTRYPOINT; and the exec form makes the script PID 1 (it
# receives signals first-hand, chapter 7). It then checks that an entrypoint
# waits for a local dependency and hands PID 1 to the app with exec. Throwaway
# images, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TAG="cap10-$$"
SHELL_NAME="cap10-shell-$$"
EXEC_NAME="cap10-exec-$$"
WAIT_SHELL_NAME="cap10-wait-shell-$$"
WAIT_EXEC_NAME="cap10-wait-exec-$$"
cleanup() {
  docker rm -f "$SHELL_NAME" "$EXEC_NAME" "$WAIT_SHELL_NAME" "$WAIT_EXEC_NAME" >/dev/null 2>&1 || true
  docker rmi -f "$TAG-shell" "$TAG-exec" "$TAG-wait-shell" "$TAG-wait-exec" "$TAG" >/dev/null 2>&1 || true
}
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

docker build -q -t "$TAG" "$HERE" >/dev/null

# 1. ENTRYPOINT + CMD: no run args -> ENTRYPOINT runs with the default CMD args
args_default=$(docker run --rm "$TAG" | sed -n 's/^args=//p')
if [ "$args_default" != "default" ]; then
  echo "UNEXPECTED: with no args, args='$args_default', expected 'default'" >&2; exit 1
fi
echo "OK 1 - ENTRYPOINT + CMD: default args reach the entrypoint (args=$args_default)"

# 2. run args override CMD but leave ENTRYPOINT in place
args_over=$(docker run --rm "$TAG" foo bar | sed -n 's/^args=//p')
if [ "$args_over" != "foo bar" ]; then
  echo "UNEXPECTED: with 'foo bar', args='$args_over', expected 'foo bar'" >&2; exit 1
fi
echo "OK 2 - run args override CMD, ENTRYPOINT stays (args=$args_over)"

# 3. exec form -> the script is PID 1 (no wrapping shell), so it gets the signals
self_pid=$(docker run --rm "$TAG" | sed -n 's/^self_pid=//p')
if [ "$self_pid" != "1" ]; then
  echo "UNEXPECTED: script self_pid=$self_pid, expected 1 (exec form should be PID 1)" >&2; exit 1
fi
echo "OK 3 - exec form: the script is PID 1 (self_pid=$self_pid) - it receives SIGTERM directly"

# 4. identical images except for CMD form: shell form consumes the stop timeout,
# while exec form delivers SIGTERM directly to the trapping application.
docker build -q -t "$TAG-shell" -f "$HERE/Dockerfile.shell" "$HERE" >/dev/null
docker build -q -t "$TAG-exec" -f "$HERE/Dockerfile.exec" "$HERE" >/dev/null
docker run -d --name "$SHELL_NAME" "$TAG-shell" >/dev/null
docker run -d --name "$EXEC_NAME" "$TAG-exec" >/dev/null
started=$(date +%s%N); docker stop -t 2 "$SHELL_NAME" >/dev/null; shell_ms=$(( ($(date +%s%N) - started) / 1000000 ))
started=$(date +%s%N); docker stop -t 2 "$EXEC_NAME" >/dev/null; exec_ms=$(( ($(date +%s%N) - started) / 1000000 ))
if [ "$shell_ms" -lt 1500 ] || [ "$exec_ms" -ge 1500 ]; then
  echo "UNEXPECTED: stop times shell=${shell_ms}ms exec=${exec_ms}ms" >&2; exit 1
fi
echo "OK 4 - CMD signal delivery: shell form ${shell_ms}ms, exec form ${exec_ms}ms"

# 5. A real entrypoint waits for a delayed local dependency, then execs the
# application. Exec-form ENTRYPOINT lets the app inherit PID 1; shell form
# keeps the wrapping shell as PID 1.
docker build -q -t "$TAG-wait-shell" -f "$HERE/Dockerfile.wait-shell" "$HERE" >/dev/null
docker build -q -t "$TAG-wait-exec" -f "$HERE/Dockerfile.wait-exec" "$HERE" >/dev/null
wait_started=$(date +%s%N)
docker run -d --name "$WAIT_SHELL_NAME" "$TAG-wait-shell" >/dev/null
docker run -d --name "$WAIT_EXEC_NAME" "$TAG-wait-exec" >/dev/null
sleep 0.5
if docker logs "$WAIT_SHELL_NAME" 2>&1 | grep -q '^self_pid=' ||
   docker logs "$WAIT_EXEC_NAME" 2>&1 | grep -q '^self_pid='; then
  echo "UNEXPECTED: an application started before its dependency was ready" >&2; exit 1
fi
docker wait "$WAIT_SHELL_NAME" "$WAIT_EXEC_NAME" >/dev/null
wait_ms=$(( ($(date +%s%N) - wait_started) / 1000000 ))
wait_shell_pid=$(docker logs "$WAIT_SHELL_NAME" 2>&1 | sed -n 's/^self_pid=//p')
wait_exec_pid=$(docker logs "$WAIT_EXEC_NAME" 2>&1 | sed -n 's/^self_pid=//p')
if [ "$wait_ms" -lt 1500 ] || [ "$wait_exec_pid" != "1" ] || [ "$wait_shell_pid" = "1" ] || [ -z "$wait_shell_pid" ]; then
  echo "UNEXPECTED: wait=${wait_ms}ms shell app PID=$wait_shell_pid exec app PID=$wait_exec_pid" >&2; exit 1
fi
echo "OK 5 - entrypoint waited ${wait_ms}ms; app PID: shell=$wait_shell_pid, exec=$wait_exec_pid"

echo
echo "ALL CHECKS PASSED"
