#!/usr/bin/env bash
set -euo pipefail

# Chapter 6 — set up an isolated control node and verify it.
# Run it from this folder:  bash setup.sh

DIR=$(cd "$(dirname "$0")" && pwd)
VENV="$DIR/.venv"

# ansible-core 2.19 needs Python >= 3.11. If your python3 is older, pick a newer
# interpreter:  PYTHON=python3.11 bash setup.sh
PY="${PYTHON:-python3}"
"$PY" -c 'import sys; sys.exit(sys.version_info < (3, 11))' \
  || { echo "ansible-core 2.19 needs Python >= 3.11: re-run with  PYTHON=python3.11 bash setup.sh" >&2; exit 1; }

# An isolated box, so we never touch the system Python. We call its binaries by
# full path; in an interactive shell you would run  . .venv/bin/activate  instead.
"$PY" -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$DIR/requirements.txt"

echo "== ansible --version =="
"$VENV/bin/ansible" --version | head -3

echo "== the command family =="
for c in ansible ansible-playbook ansible-config ansible-doc ansible-galaxy; do
  test -x "$VENV/bin/$c" && echo "  $c: OK"
done

echo "== smoke test: ansible localhost -m ping =="
"$VENV/bin/ansible" localhost -m ping

echo
echo "control node ready. Activate the venv in your shell with:  . $VENV/bin/activate"
