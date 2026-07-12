#!/usr/bin/env bash
# cap24 - solution test. Molecule end-to-end on a real throwaway Docker container:
# create, converge, idempotence, verify, destroy. Then it proves the two gates bite:
# idempotence catches a non-idempotent role, and the Testinfra verifier catches a
# wrong result. Needs a working local Docker engine. Molecule only ever manages the
# instance it names (cap24-instance) - it never touches your other containers.
#
# The venv is ACTIVATED (not called by path): the molecule docker driver runs its
# create/destroy in a detached async worker that mis-initialises unless VIRTUAL_ENV
# and PATH point at the venv, otherwise it fails with a spurious "http+docker".
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)

if ! docker info >/dev/null 2>&1; then
  echo "This exercise needs a working local Docker engine (docker info failed)." >&2
  exit 1
fi

WORK=$(mktemp -d)
# Isolate the collections we install (community.docker etc.) from the user's own.
export ANSIBLE_COLLECTIONS_PATH="$WORK/collections"
VENV="$WORK/venv"
ROLE="$WORK/role/cap24_app"

cleanup() {
  if [ -d "$ROLE" ]; then
    ( cd "$ROLE" && molecule destroy ) >/dev/null 2>&1 || true
  fi
  docker rm -f cap24-instance >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

python3 -m venv "$VENV"
# shellcheck disable=SC1091
. "$VENV/bin/activate"
pip -q install -r "$HERE/requirements.txt"
ansible-galaxy collection install -r "$HERE/requirements.yml" \
  -p "$ANSIBLE_COLLECTIONS_PATH" >/dev/null

# work on a copy so the shipped files are never mutated
mkdir -p "$WORK/role"
cp -r "$HERE/cap24_app" "$WORK/role/"
cd "$ROLE"

# --- 1. the whole lifecycle is green ---
if ! molecule test >"$WORK/test.log" 2>&1; then
  echo "UNEXPECTED: molecule test failed on the solution" >&2
  tail -20 "$WORK/test.log" >&2
  exit 1
fi
grep -q 'Idempotence completed successfully' "$WORK/test.log" \
  || { echo "UNEXPECTED: the idempotence phase did not run" >&2; exit 1; }
echo "OK 1 - molecule test green (create, converge, idempotence, verify, destroy)"

# --- 2. the idempotence gate catches a non-idempotent role ---
# swap in the start role: a command with no 'creates' guard - changed on every run
cp "$HERE/../start/cap24_app/tasks/main.yml" tasks/main.yml
molecule create   >/dev/null 2>&1
molecule converge >/dev/null 2>&1
set +e
molecule idempotence >"$WORK/idem.log" 2>&1
idem_rc=$?
set -e
if [ "$idem_rc" -eq 0 ] || ! grep -q 'Idempotence test failed' "$WORK/idem.log"; then
  echo "UNEXPECTED: idempotence did not catch the non-idempotent role" >&2
  exit 1
fi
echo "OK 2 - idempotence gate catches the non-idempotent start role (exit $idem_rc)"

# --- 3. the Testinfra verifier catches a wrong result ---
cat > molecule/default/tests/test_tamper.py <<'PY'
testinfra_hosts = ["all"]


def test_wrong_expectation(host):
    conf = host.file("/etc/cap24app/app.conf")
    assert "workers = 999" in conf.content_string
PY
set +e
molecule verify >/dev/null 2>&1
verify_rc=$?
set -e
if [ "$verify_rc" -eq 0 ]; then
  echo "UNEXPECTED: verify did not catch the wrong expectation" >&2
  exit 1
fi
echo "OK 3 - verify gate catches a wrong expectation (exit $verify_rc)"
molecule destroy >/dev/null 2>&1

# --- 4. isolation: teardown leaves no cap24 container behind ---
if docker ps -a --format '{{.Names}}' | grep -qx 'cap24-instance'; then
  echo "UNEXPECTED: a cap24-instance container was left behind" >&2
  exit 1
fi
echo "OK 4 - no cap24 container left behind; teardown is clean"

echo
echo "ALL CHECKS PASSED"
