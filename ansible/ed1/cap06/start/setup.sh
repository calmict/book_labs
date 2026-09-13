#!/usr/bin/env bash
set -euo pipefail

# Chapter 6 — set up an isolated control node and verify it (starting point).
# Run it from this folder:  bash setup.sh

DIR=$(cd "$(dirname "$0")" && pwd)
VENV="$DIR/.venv"

# ansible-core 2.19 needs Python >= 3.11. If your python3 is older, pick a newer
# interpreter:  PYTHON=python3.11 bash setup.sh
PY="${PYTHON:-python3}"
"$PY" -c 'import sys; sys.exit(sys.version_info < (3, 11))' \
  || { echo "ansible-core 2.19 needs Python >= 3.11: re-run with  PYTHON=python3.11 bash setup.sh" >&2; exit 1; }

# TODO 1: create a virtualenv (an isolated box, so you never touch the system
# Python) and use its pip to install from requirements.txt. Add the two commands
# here, ABOVE the guard below:
#
#   "$PY" -m venv "$VENV"
#   "$VENV/bin/pip" install -q -r "$DIR/requirements.txt"
#
# (In an interactive shell you would usually run  . .venv/bin/activate  to put the
# venv on your PATH; here we call its binaries by full path.)

if [ ! -x "$VENV/bin/ansible" ]; then
  echo "Complete TODO 1 (create the venv and install ansible-core), then re-run."
  echo "And do not forget TODO 2: pin ansible-core in requirements.txt."
  exit 1
fi

# ---- verification (runs once TODO 1 and TODO 2 are done) ----
echo "== ansible --version =="
"$VENV/bin/ansible" --version | head -3

echo "== the command family =="
for c in ansible ansible-playbook ansible-config ansible-doc ansible-galaxy; do
  test -x "$VENV/bin/$c" && echo "  $c: OK"
done

echo "== smoke test: ansible localhost -m ping =="
"$VENV/bin/ansible" localhost -m ping
