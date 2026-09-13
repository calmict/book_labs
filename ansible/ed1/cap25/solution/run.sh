#!/usr/bin/env bash
# cap25 - solution test. Times the tuned rollout against the slow starting one
# and proves the three levers pay off: forks (whole fleet in one wave), a free
# strategy (no per-task barrier) and gather_facts: false (no unused setup).
# Node-less: a fleet of 12 local hosts, a sleep standing in for per-host work,
# so it runs anywhere and costs nothing.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
VENV="$WORK/venv"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# ansible-core 2.19 needs Python >= 3.11 on the control node: take the first
# interpreter that has it (plain python3 on recent systems).
PY=""
for cand in python3.13 python3.12 python3.11 python3; do
  if command -v "$cand" >/dev/null 2>&1 \
    && "$cand" -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then
    PY=$cand
    break
  fi
done
[ -n "$PY" ] || { echo "ERROR: Python >= 3.11 not found (ansible-core 2.19 needs it)" >&2; exit 1; }
"$PY" -m venv "$VENV"
# shellcheck disable=SC1091
. "$VENV/bin/activate"
pip -q install -r "$HERE/requirements.txt"

# profile_tasks lives in the ansible.posix collection, not in ansible-core:
# install the pinned collection into the workdir, so the test never leans on a
# copy the machine happens to have.
export ANSIBLE_COLLECTIONS_PATH="$WORK/collections"
ansible-galaxy collection install -r "$HERE/requirements.yml" \
  -p "$ANSIBLE_COLLECTIONS_PATH" >/dev/null

# Run a rollout with the profile_tasks callback, capturing wall seconds on
# stdout and the full output (which lists per-task timings) in a log.
run_timed() {  # $1 = playbook dir, $2 = log name
  ( cd "$1"
    SECONDS=0
    ANSIBLE_CALLBACKS_ENABLED=ansible.posix.profile_tasks \
      ansible-playbook deploy.yml >"$WORK/$2.log" 2>&1
    echo "$SECONDS" )
}

sol_s=$(run_timed "$HERE" solution)
start_s=$(run_timed "$HERE/../start" start)
echo "Timing - tuned rollout ${sol_s}s vs starting rollout ${start_s}s"

# --- 1. the tuned rollout is clearly faster (> 1.5x) ---
if [ "$start_s" -lt $(( sol_s * 3 / 2 )) ]; then
  echo "UNEXPECTED: the tuned rollout was not clearly faster (${sol_s}s vs ${start_s}s)" >&2
  exit 1
fi
echo "OK 1 - tuned rollout clearly faster (${sol_s}s vs ${start_s}s)"

# --- 2. profile_tasks shows the fact-gathering cost in start, gone in solution ---
# First prove the callback really ran: without it the playbook still succeeds,
# and the plain output still prints "Gathering Facts", so a check on that string
# alone would pass having measured nothing.
for log in start solution; do
  if grep -q 'Skipping callback plugin' "$WORK/$log.log"; then
    echo "UNEXPECTED: profile_tasks did not load for the $log rollout" >&2
    exit 1
  fi
  if ! grep -Eq ' -+ [0-9.]+s$' "$WORK/$log.log"; then
    echo "UNEXPECTED: the $log rollout printed no profile_tasks timings" >&2
    exit 1
  fi
done
# the timed "Gathering Facts ---- 7.35s" line is printed by profile_tasks alone
if ! grep -Eq '^Gathering Facts -+ [0-9.]+s$' "$WORK/start.log"; then
  echo "UNEXPECTED: the starting profile shows no fact-gathering cost" >&2
  exit 1
fi
if grep -q 'Gathering Facts' "$WORK/solution.log"; then
  echo "UNEXPECTED: the tuned rollout still gathers facts" >&2
  exit 1
fi
echo "OK 2 - profile_tasks shows facts cost in start, absent in solution"

# --- 3. the three levers are actually set in the solution ---
grep -Eq '^forks *= *12' "$HERE/ansible.cfg" \
  || { echo "UNEXPECTED: forks is not 12 in ansible.cfg" >&2; exit 1; }
grep -q 'strategy: free' "$HERE/deploy.yml" \
  || { echo "UNEXPECTED: strategy: free is not set in deploy.yml" >&2; exit 1; }
grep -q 'gather_facts: false' "$HERE/deploy.yml" \
  || { echo "UNEXPECTED: gather_facts: false is not set in deploy.yml" >&2; exit 1; }
echo "OK 3 - the three levers are set (forks 12, strategy free, gather_facts false)"

echo
echo "ALL CHECKS PASSED"
