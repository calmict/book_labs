#!/usr/bin/env bash
# cap01 - solution test. Builds a container by hand with unshare (no Docker) and
# proves it is just a Linux process: PID 1 inside a new PID namespace, an
# isolated hostname, and a pid-namespace inode different from the host's. Then it
# shows the gate bites - drop the --pid flag and the "container" is no longer
# isolated (its inside PID is not 1). Rootless: no sudo, runs anywhere.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

val() { grep "^$2=" "$1" | cut -d= -f2-; }

# --- build the bare-hands container and read the two points of view ---
"$HERE/manibnude.sh" "$WORK"
inside_pid=$(val "$WORK/inside.txt" inside_pid)
inside_hostname=$(val "$WORK/inside.txt" inside_hostname)
inside_pidns=$(val "$WORK/inside.txt" inside_pidns)
host_hostname=$(val "$WORK/host.txt" host_hostname)
host_pidns=$(val "$WORK/host.txt" host_pidns)

# --- 1. inside the namespace, our shell is PID 1 ---
if [ "$inside_pid" != "1" ]; then
  echo "UNEXPECTED: inside PID is $inside_pid, not 1 - the PID namespace was not created" >&2
  exit 1
fi
echo "OK 1 - inside the new PID namespace our shell is PID 1"

# --- 2. the hostname is isolated (UTS): changed inside, untouched on the host ---
if [ "$inside_hostname" != "nave-cargo" ] || [ "$host_hostname" = "nave-cargo" ]; then
  echo "UNEXPECTED: hostname not isolated (inside=$inside_hostname host=$host_hostname)" >&2
  exit 1
fi
echo "OK 2 - the hostname is isolated (inside nave-cargo, host $host_hostname untouched)"

# --- 3. the pid-namespace inode differs from the host's: a separate world ---
if [ "$inside_pidns" = "$host_pidns" ]; then
  echo "UNEXPECTED: inside and host share the same PID namespace ($inside_pidns)" >&2
  exit 1
fi
echo "OK 3 - the container lives in a different PID namespace ($inside_pidns vs host $host_pidns)"

# --- 4. the gate bites: without --pid there is no new PID namespace ---
nopid=$(unshare --user --map-root-user --uts --fork bash -c 'echo $$' 2>/dev/null || echo FAILED)
if [ "$nopid" = "1" ]; then
  echo "UNEXPECTED: without --pid the inside PID was still 1" >&2
  exit 1
fi
echo "OK 4 - drop --pid and the isolation is gone (inside PID $nopid, not 1)"

echo
echo "ALL CHECKS PASSED"
