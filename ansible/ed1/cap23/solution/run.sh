#!/usr/bin/env bash
# cap23 - solution test. The three-level validation net, node-less on localhost:
# --syntax-check, ansible-lint (at a declared profile), and check mode with --diff.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

WORK=$(mktemp -d)
VENV="$WORK/venv"
export CAP23_LAB="$WORK/lab"
export ANSIBLE_LOCALHOST_WARNING=False

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

python3 -m venv "$VENV"
"$VENV/bin/pip" -q install -r requirements.txt
AP="$VENV/bin/ansible-playbook"
AL="$VENV/bin/ansible-lint"

# --- 1. --syntax-check: the structure is valid ---
"$AP" --syntax-check -i localhost, site.yml >/dev/null 2>&1 \
  || { echo "UNEXPECTED: --syntax-check failed" >&2; exit 1; }
echo "OK 1 - --syntax-check passes"

# --- 2. ansible-lint passes on the clean playbook, at the declared profile ---
if ! "$AL" --nocolor site.yml >/dev/null 2>&1; then
  echo "UNEXPECTED: ansible-lint failed on the clean playbook" >&2
  "$AL" --nocolor site.yml 2>&1 | tail -5
  exit 1
fi
grep -q 'profile: production' .ansible-lint \
  || { echo "UNEXPECTED: .ansible-lint does not pin the production profile" >&2; exit 1; }
echo "OK 2 - ansible-lint passes at the declared production profile"

# --- 3. ansible-lint CATCHES the sloppy starting playbook ---
if "$AL" --nocolor --profile production ../start/site.yml >/dev/null 2>&1; then
  echo "UNEXPECTED: ansible-lint did not catch the sloppy start playbook" >&2
  exit 1
fi
echo "OK 3 - ansible-lint catches the violations in the start playbook"

# --- 4. the read task is check-mode safe (TODO 2) ---
grep -q 'check_mode: false' site.yml \
  || { echo "UNEXPECTED: the read task is not check-mode safe" >&2; exit 1; }
"$AP" -i localhost, --check site.yml >/dev/null 2>&1 \
  || { echo "UNEXPECTED: the --check run errored" >&2; exit 1; }
echo "OK 4 - the read task is check-mode safe (check_mode: false)"

# --- 5. check --diff shows the change but writes nothing ---
rm -rf "$CAP23_LAB"
"$AP" -i localhost, --check --diff site.yml > "$WORK/diff.txt" 2>&1
if test -f "$CAP23_LAB/conf.txt"; then
  echo "UNEXPECTED: check mode wrote the file" >&2
  exit 1
fi
grep -q 'mode = production' "$WORK/diff.txt" \
  || { echo "UNEXPECTED: --diff did not show the change" >&2; cat "$WORK/diff.txt"; exit 1; }
echo "OK 5 - check mode showed the diff but wrote nothing"

# --- 6. the real run writes it; a rerun is idempotent ---
"$AP" -i localhost, site.yml >/dev/null 2>&1
grep -qx 'mode = production' "$CAP23_LAB/conf.txt" 2>/dev/null \
  || { echo "UNEXPECTED: the real run did not write conf.txt" >&2; exit 1; }
"$AP" -i localhost, site.yml > "$WORK/rerun.txt" 2>&1
grep -qE 'localhost[[:space:]]+: ok=[0-9]+[[:space:]]+changed=0' "$WORK/rerun.txt" \
  || { echo "UNEXPECTED: the rerun was not idempotent" >&2; grep localhost "$WORK/rerun.txt"; exit 1; }
echo "OK 6 - the real run wrote conf.txt; rerun is idempotent (changed=0)"

echo
echo "ALL CHECKS PASSED"
