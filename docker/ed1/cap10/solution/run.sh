#!/usr/bin/env bash
# cap10 - solution test. Builds the ENTRYPOINT/CMD image and checks: running with
# no arguments, ENTRYPOINT runs with CMD's default arguments; run arguments
# override CMD but not ENTRYPOINT; and the exec form makes the script PID 1 (it
# receives signals first-hand, chapter 7). Throwaway image, no restart, no
# privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TAG="cap10-$$"
cleanup() { docker rmi -f "$TAG" >/dev/null 2>&1 || true; }
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

echo
echo "ALL CHECKS PASSED"
