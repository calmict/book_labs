#!/usr/bin/env bash
# cap22 - solution test. Node-less (connection: local, four local hosts): the
# resilience patterns for a fleet where something goes wrong. No containers.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

WORK=$(mktemp -d)
VENV="$WORK/venv"

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

python3 -m venv "$VENV"
"$VENV/bin/pip" -q install -r requirements.txt
AP="$VENV/bin/ansible-playbook"

# --- 1. the resilient deploy runs green across the fleet ---
export CAP22_LAB="$WORK/lab"
if ! "$AP" -i inventory.ini site.yml > "$WORK/run1.txt" 2>&1; then
  echo "UNEXPECTED: the deploy failed overall" >&2
  cat "$WORK/run1.txt"
  exit 1
fi
grep -qE 'db1[[:space:]]+: ok=[0-9]+.*rescued=1' "$WORK/run1.txt" \
  || { echo "UNEXPECTED: db1 was not rescued" >&2; grep db1 "$WORK/run1.txt"; exit 1; }
echo "OK 1 - the deploy survived the failure on db1 (rescued, play not failed)"

# --- 2. block/rescue/always: rollback only where it failed, cleanup everywhere ---
test -f "$CAP22_LAB/db1.rollback"  || { echo "UNEXPECTED: db1 was not rolled back" >&2; exit 1; }
test -f "$CAP22_LAB/db1.cleanup"   || { echo "UNEXPECTED: db1 was not cleaned up" >&2; exit 1; }
test -f "$CAP22_LAB/web1.cleanup"  || { echo "UNEXPECTED: web1 was not cleaned up" >&2; exit 1; }
if test -f "$CAP22_LAB/web1.rollback"; then
  echo "UNEXPECTED: web1 rolled back but it did not fail" >&2
  exit 1
fi
echo "OK 2 - rescue ran only on db1; always cleaned up every host"

# --- 3. until/retries: the flaky health check was retried until healthy ---
[ "$(wc -l < "$CAP22_LAB/web1.hc")" -ge 3 ] \
  || { echo "UNEXPECTED: the health check was not retried" >&2; exit 1; }
echo "OK 3 - the slow health check was retried until it passed"

# --- 4. ignore_errors + failed_when kept the play green ---
grep -qE 'web1[[:space:]]+: ok=[0-9]+.*ignored=1' "$WORK/run1.txt" \
  || { echo "UNEXPECTED: the ignored failure was not ignored" >&2; grep web1 "$WORK/run1.txt"; exit 1; }
echo "OK 4 - ignore_errors and failed_when redefined what counts as failure"

# --- 5. force_handlers: the notified handler ran ---
test -f "$CAP22_LAB/web1.reloaded" \
  || { echo "UNEXPECTED: the notified handler did not run" >&2; exit 1; }
echo "OK 5 - the notified handler ran"

# --- 6. assert fails fast: a bad deploy_env writes nothing ---
export CAP22_LAB="$WORK/lab_bad"
if "$AP" -i inventory.ini site.yml -e deploy_env=banana > "$WORK/bad.txt" 2>&1; then
  echo "UNEXPECTED: a bad deploy_env did not fail" >&2
  exit 1
fi
if ls "$WORK"/lab_bad/*.deployed >/dev/null 2>&1; then
  echo "UNEXPECTED: something was deployed despite the bad env" >&2
  exit 1
fi
echo "OK 6 - assert failed fast; nothing was deployed with a bad deploy_env"

# --- 7. any_errors_fatal: one failure aborts the rollout for everyone ---
export CAP22_LAB="$WORK/lab"
"$AP" -i inventory.ini failfast.yml > "$WORK/ff.txt" 2>&1 || true
if grep -q 'ROLLOUT on' "$WORK/ff.txt"; then
  echo "UNEXPECTED: the rollout reached a host despite any_errors_fatal" >&2
  exit 1
fi
echo "OK 7 - any_errors_fatal aborted the rollout before it reached anyone"

# --- 8. force_handlers survives a later failure ---
rm -f "$CAP22_LAB/fh.done"
"$AP" -i inventory.ini handlers.yml > "$WORK/fh.txt" 2>&1 || true
test -f "$CAP22_LAB/fh.done" \
  || { echo "UNEXPECTED: the handler was lost after the failure" >&2; cat "$WORK/fh.txt"; exit 1; }
echo "OK 8 - force_handlers ran the pending handler despite a later failure"

echo
echo "ALL CHECKS PASSED"
