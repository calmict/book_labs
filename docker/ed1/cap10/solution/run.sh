#!/usr/bin/env bash
# cap10 - solution test. Builds the ENTRYPOINT/CMD image and checks: running with
# no arguments, ENTRYPOINT runs with CMD's default arguments; run arguments
# override CMD but not ENTRYPOINT; and the exec form makes the script PID 1 (it
# receives signals first-hand, chapter 7). Then it times the shutdown of the same
# script started in three ways - exec form, shell form with the shell still in the
# way, shell form where the shell steps aside - and reads who was PID 1 in each.
# Throwaway images, a shortened grace period, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TAG="cap10-$$"
TAG_STAYS="cap10-shell-stays-$$"
TAG_ALONE="cap10-shell-alone-$$"
GRACE=5
cleanup() { docker rmi -f "$TAG" "$TAG_STAYS" "$TAG_ALONE" >/dev/null 2>&1 || true; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

docker build -q -t "$TAG" "$HERE" >/dev/null
docker build -q -t "$TAG_STAYS" -f "$HERE/Dockerfile.shell-stays" "$HERE" >/dev/null
docker build -q -t "$TAG_ALONE" -f "$HERE/Dockerfile.shell-alone" "$HERE" >/dev/null

# Starts a serving container, stops it with a shortened grace period and reports
# how long the stop took, the exit code, and the PID the script saw for itself.
time_stop() {
  local image=$1 cid elapsed t0 t1
  cid=$(docker run -d "$image" "${@:2}")
  until docker logs "$cid" 2>/dev/null | grep -q '^self_pid='; do sleep 0.2; done
  t0=$(date +%s%N); docker stop -t "$GRACE" "$cid" >/dev/null; t1=$(date +%s%N)
  elapsed=$(( (t1 - t0) / 1000000 ))
  printf '%s %s %s\n' \
    "$elapsed" \
    "$(docker inspect -f '{{.State.ExitCode}}' "$cid")" \
    "$(docker logs "$cid" 2>/dev/null | sed -n 's/^self_pid=//p' | head -1)"
  docker rm -f "$cid" >/dev/null 2>&1 || true
}

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

# 4. The same script, stopped in two forms: exec answers, the shell that stays
#    does not - the grace period expires and the kernel kills the container.
read -r exec_ms exec_code exec_pid < <(time_stop "$TAG" serve)
read -r stays_ms stays_code stays_pid < <(time_stop "$TAG_STAYS")
if [ "$exec_pid" != "1" ] || [ "$exec_code" != "0" ] || [ "$exec_ms" -gt $(( GRACE * 1000 - 1500 )) ]; then
  echo "UNEXPECTED: exec form stopped in ${exec_ms}ms with code $exec_code as PID $exec_pid," >&2
  echo "            expected a prompt exit 0 from PID 1" >&2; exit 1
fi
if [ "$stays_pid" = "1" ] || [ "$stays_code" != "137" ] || [ "$stays_ms" -lt $(( GRACE * 1000 - 1000 )) ]; then
  echo "UNEXPECTED: the shell form stopped in ${stays_ms}ms with code $stays_code as PID $stays_pid," >&2
  echo "            expected the grace period to expire and a kill (137)" >&2; exit 1
fi
echo "OK 4 - exec form: stopped in ${exec_ms}ms, exit $exec_code, script was PID $exec_pid;"
echo "       shell form with the shell in the way: ${stays_ms}ms, exit $stays_code (killed), script was PID $stays_pid"

# 5. The condition behind the rule: with the script as the shell's only command,
#    busybox's shell replaces itself with it, PID 1 is the script again, and the
#    stop is prompt. Shell form is not slow by itself - a shell in the way is.
read -r alone_ms alone_code alone_pid < <(time_stop "$TAG_ALONE")
if [ "$alone_pid" != "1" ] || [ "$alone_code" != "0" ] || [ "$alone_ms" -gt $(( GRACE * 1000 - 1500 )) ]; then
  echo "UNEXPECTED: the lone shell form stopped in ${alone_ms}ms with code $alone_code as PID $alone_pid," >&2
  echo "            expected the shell to step aside and leave the script as PID 1" >&2; exit 1
fi
echo "OK 5 - shell form, script alone: the shell steps aside, script is PID $alone_pid again,"
echo "       stopped in ${alone_ms}ms with exit $alone_code - the cost is the shell that stays, not the form"

echo
echo "ALL CHECKS PASSED"
