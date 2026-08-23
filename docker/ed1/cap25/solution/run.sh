#!/usr/bin/env bash
# cap25 - solution test. Proves observability: docker logs retrieves both the stdout
# and stderr lines the container wrote; the container's logging driver is json-file;
# and docker stats reports a live memory metric. Throwaway container, no restart, no
# privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/iobs.sh" "$WORK"
stdout_seen=$(val "$WORK/obs.txt" stdout_seen)
stderr_seen=$(val "$WORK/obs.txt" stderr_seen)
driver=$(val "$WORK/obs.txt" driver)
mem=$(val "$WORK/obs.txt" mem)
unrotated_bytes=$(val "$WORK/obs.txt" unrotated_bytes)
rotated_bytes=$(val "$WORK/obs.txt" rotated_bytes)
stats_limit=$(val "$WORK/obs.txt" stats_limit)
configured_limit=$(val "$WORK/obs.txt" configured_limit)

# 1. docker logs captured both stdout and stderr
if [ "$stdout_seen" -lt 1 ] || [ "$stderr_seen" -lt 1 ]; then
  echo "UNEXPECTED: logs missing a stream (stdout_seen=$stdout_seen stderr_seen=$stderr_seen)" >&2; exit 1
fi
echo "OK 1 - docker logs captured stdout and stderr"

# 2. the logging driver is json-file (where the logs are kept)
if [ "$driver" != "json-file" ]; then
  echo "UNEXPECTED: logging driver is '$driver', expected json-file" >&2; exit 1
fi
echo "OK 2 - logging driver is json-file"

# 3. docker stats reports a live memory metric (non-empty, contains a size)
case "$mem" in
  *[0-9]*) ;;
  *) echo "UNEXPECTED: docker stats returned no memory metric (mem='$mem')" >&2; exit 1 ;;
esac
echo "OK 3 - docker stats reports live memory usage ($mem)"

# 4. direct file-size comparison: rotation bounds the chatty workload.
if [ "$unrotated_bytes" -le 50000 ] || [ "$rotated_bytes" -ge 50000 ] || [ "$unrotated_bytes" -le "$rotated_bytes" ]; then
  echo "UNEXPECTED: log sizes unrotated=$unrotated_bytes rotated=$rotated_bytes" >&2; exit 1
fi
echo "OK 4 - log rotation bounds files: unrotated=${unrotated_bytes}B, rotated=${rotated_bytes}B"

# 5. stats LIMIT corresponds to the configured 64 MiB (binary or decimal display).
if [ "$configured_limit" != 67108864 ]; then
  echo "UNEXPECTED: configured memory limit is $configured_limit bytes" >&2; exit 1
fi
case "$stats_limit" in 64MiB|67.11MB|67.1MB) ;; *) echo "UNEXPECTED: stats LIMIT is '$stats_limit', expected 64MiB" >&2; exit 1;; esac
echo "OK 5 - docker stats LIMIT $stats_limit matches --memory=64MiB ($configured_limit bytes)"

echo
echo "ALL CHECKS PASSED"
