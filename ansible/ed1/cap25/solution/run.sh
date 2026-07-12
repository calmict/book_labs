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

python3 -m venv "$VENV"
# shellcheck disable=SC1091
. "$VENV/bin/activate"
pip -q install -r "$HERE/requirements.txt"

# Run a rollout with the profile_tasks callback, capturing wall seconds on
# stdout and the full output (which lists per-task timings) in a log.
run_timed() {  # $1 = playbook dir, $2 = log name
  ( cd "$1"
    SECONDS=0
    ANSIBLE_CALLBACKS_ENABLED=profile_tasks \
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
if ! grep -q 'Gathering Facts' "$WORK/start.log"; then
  echo "UNEXPECTED: the starting rollout did not gather facts" >&2
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
