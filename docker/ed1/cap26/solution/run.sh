#!/usr/bin/env bash
# cap26 - solution test. Proves you can diagnose a mute, crash-looping container: its
# logs are empty (nothing to read there), docker inspect reveals the exit code (42,
# the real diagnosis), and the restart counter plus the final state show the crash
# loop that gave up. Throwaway container, no restart of the daemon, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/idiag.sh" "$WORK"
logs_len=$(val "$WORK/diag.txt" logs_len)
exit_code=$(val "$WORK/diag.txt" exit_code)
restart_count=$(val "$WORK/diag.txt" restart_count)
status=$(val "$WORK/diag.txt" status)

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

echo
echo "ALL CHECKS PASSED"
