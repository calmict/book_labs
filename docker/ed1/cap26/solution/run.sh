#!/usr/bin/env bash
# cap26 - solution test. Proves you can diagnose a mute, crash-looping container: its
# logs are empty (nothing to read there), docker inspect reveals the exit code (42,
# the real diagnosis), and the restart counter plus the final state show the crash
# loop that gave up. It also verifies OOM evidence, command-not-found semantics and
# shellless process inspection. Throwaway resources, no daemon restart or privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/troubleshoot.sh" "$WORK"
logs_len=$(val "$WORK/diag.txt" logs_len)
exit_code=$(val "$WORK/diag.txt" exit_code)
restart_count=$(val "$WORK/diag.txt" restart_count)
status=$(val "$WORK/diag.txt" status)
oom_exit_code=$(val "$WORK/diag.txt" oom_exit_code)
oom_killed=$(val "$WORK/diag.txt" oom_killed)
shell_run_code=$(val "$WORK/diag.txt" shell_run_code)
shell_exit_code=$(val "$WORK/diag.txt" shell_exit_code)
shell_error=$(val "$WORK/diag.txt" shell_error)
direct_start_code=$(val "$WORK/diag.txt" direct_start_code)
direct_status=$(val "$WORK/diag.txt" direct_status)
direct_error=$(val "$WORK/diag.txt" direct_error)
shellless_exec_code=$(val "$WORK/diag.txt" shellless_exec_code)

# 1. the container is mute: no logs
if [ "$logs_len" != "0" ]; then
  echo "UNEXPECTED: the container was not mute (logs_len=$logs_len)" >&2; exit 1
fi
echo "OK 1 - the container is mute: docker logs is empty"

# 2. docker inspect reveals the exit code (the real diagnosis)
if [ "$exit_code" != "42" ]; then
  echo "UNEXPECTED: exit code is '$exit_code', expected 42" >&2; exit 1
fi
echo "OK 2 - docker inspect reveals the exit code ($exit_code)"

# 3. the crash loop is visible: it restarted, then the policy gave up
case "$restart_count" in
  ''|*[!0-9]*) echo "UNEXPECTED: restart_count is not a number ('$restart_count')" >&2; exit 1 ;;
esac
if [ "$restart_count" -lt 1 ] || [ "$status" != "exited" ]; then
  echo "UNEXPECTED: no crash loop settled (restart_count=$restart_count status=$status)" >&2; exit 1
fi
echo "OK 3 - crash loop: restarted $restart_count time(s), final status '$status'"

# 4. exit 137 is SIGKILL; OOMKilled proves that memory pressure caused it
if [ "$oom_exit_code" != "137" ] || [ "$oom_killed" != "true" ]; then
  echo "UNEXPECTED: OOM evidence is exit=$oom_exit_code OOMKilled=$oom_killed" >&2; exit 1
fi
echo "OK 4 - exit 137 and OOMKilled=true confirm an out-of-memory kill"

# 5. the shell returns 127, while direct exec is rejected before the process starts
if [ "$shell_run_code" != "127" ] || [ "$shell_exit_code" != "127" ] || [ -n "$shell_error" ]; then
  echo "UNEXPECTED: shell case is run=$shell_run_code exit=$shell_exit_code error='$shell_error'" >&2; exit 1
fi
if [ "$direct_start_code" = "0" ] || [ "$direct_status" != "created" ] || [ -z "$direct_error" ]; then
  echo "UNEXPECTED: direct case is start=$direct_start_code status=$direct_status error='$direct_error'" >&2; exit 1
fi
echo "OK 5 - shell returns 127; direct exec is rejected before the process starts"

# 6. the target has no shell, but a helper sharing its PID namespace sees its process
if [ "$shellless_exec_code" = "0" ]; then
  echo "UNEXPECTED: sh ran inside the shellless container" >&2; exit 1
fi
if ! grep -Eq '[[:space:]]/sleep([[:space:]]|$)' "$WORK/processes.txt"; then
  echo "UNEXPECTED: shared PID namespace did not expose /sleep" >&2; exit 1
fi
echo "OK 6 - a helper in the shared PID namespace sees the shellless process"

echo
echo "ALL CHECKS PASSED"
