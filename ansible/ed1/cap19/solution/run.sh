#!/usr/bin/env bash
# cap19 - solution test. Proves the runtime-lookup paradigm end to end:
#   - the collection is declared and installed;
#   - the become password is a lookup, not a value in the playbook config;
#   - the play becomes root with a secret fetched from the caveau at runtime;
#   - the secret appears in no config file and in no -vvv output;
#   - the app credential is written, yet no_log keeps it out of the logs;
#   - the run is idempotent;
#   - an AppRole machine identity reads the secret under a least-privilege policy.
#
# nodes.sh deposits the secret into the caveau to stand in for the out-of-band
# population a human would do; that lab convenience is the only script that
# knows the value. The production-path config (group_vars, site.yml) never does.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

WORK=$(mktemp -d)
VENV="$WORK/venv"
COLL="$WORK/collections"

cleanup() {
  ./nodes.sh down >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# --- 0. tools, collection, platform ---
python3 -m venv "$VENV"
"$VENV/bin/pip" -q install -r requirements.txt
AP="$VENV/bin/ansible-playbook"
AG="$VENV/bin/ansible-galaxy"

"$AG" collection install -r requirements.yml -p "$COLL" >/dev/null
export ANSIBLE_COLLECTIONS_PATH="$COLL"

./nodes.sh up
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=lab-root-token

# --- 1. the collection is declared and installed ---
grep -q 'community.hashi_vault' requirements.yml \
  || { echo "UNEXPECTED: requirements.yml does not declare the collection" >&2; exit 1; }
if ! "$AG" collection list -p "$COLL" 2>/dev/null | grep -q 'community.hashi_vault'; then
  echo "UNEXPECTED: the collection is not installed" >&2
  exit 1
fi
echo "OK 1 - community.hashi_vault declared and installed"

# --- 2. the become password is a runtime lookup, not a value in the config ---
if ! grep -q "lookup('community.hashi_vault.hashi_vault'" group_vars/web/vars.yml; then
  echo "UNEXPECTED: the become password is not a hashi_vault lookup" >&2
  exit 1
fi
if grep -rq 'secops-pw' group_vars site.yml; then
  echo "UNEXPECTED: the secret is written in the playbook config" >&2
  exit 1
fi
echo "OK 2 - the become password is fetched at runtime; not in the config"

# --- 3. run at -vvv: becomes root, marker written ---
if ! "$AP" -i inventory.ini site.yml -vvv > "$WORK/run1.txt" 2>&1; then
  echo "UNEXPECTED: the playbook failed" >&2
  tail -30 "$WORK/run1.txt"
  exit 1
fi
grep -q 'became root' "$WORK/run1.txt" \
  || { echo "UNEXPECTED: did not become root" >&2; exit 1; }
docker exec cap19-web1 stat -c '%U:%G' /etc/cap19-marker.txt | grep -qx 'root:root' \
  || { echo "UNEXPECTED: the marker is not root-owned" >&2; exit 1; }
echo "OK 3 - became root with the caveau-fetched password; marker written"

# --- 4. the secret leaks nowhere: not in the -vvv log ---
if grep -q 'secops-pw' "$WORK/run1.txt"; then
  echo "UNEXPECTED: the become password leaked into the -vvv output" >&2
  exit 1
fi
if grep -q 'app-db-pw' "$WORK/run1.txt"; then
  echo "UNEXPECTED: the app credential leaked into the -vvv output" >&2
  exit 1
fi
echo "OK 4 - neither secret appears in the -vvv output"

# --- 5. the app credential was written despite no_log ---
docker exec cap19-web1 cat /etc/myapp/db.conf | grep -qx 'db_password=app-db-pw' \
  || { echo "UNEXPECTED: db.conf was not written correctly" >&2; exit 1; }
echo "OK 5 - the app credential was written (the no_log task did its work)"

# --- 6. no_log hid that task at -vvv ---
grep -q 'output has been hidden' "$WORK/run1.txt" \
  || { echo "UNEXPECTED: no_log did not hide the credential task" >&2; exit 1; }
echo "OK 6 - no_log hid the credential task from the logs"

# --- 7. idempotence: a second run changes nothing ---
"$AP" -i inventory.ini site.yml > "$WORK/run2.txt" 2>&1
if ! grep -qE 'web1[[:space:]]+: ok=[0-9]+[[:space:]]+changed=0[[:space:]]' "$WORK/run2.txt"; then
  echo "UNEXPECTED: the rerun was not idempotent" >&2
  grep 'web1' "$WORK/run2.txt"
  exit 1
fi
echo "OK 7 - rerun is idempotent (changed=0)"

# --- 8. AppRole machine identity reads the scoped secret ---
if ! "$AP" -i inventory.ini approle.yml \
     -e role_id="$(cat /tmp/cap19-lab/role_id)" \
     -e secret_id="$(cat /tmp/cap19-lab/secret_id)" > "$WORK/approle.txt" 2>&1; then
  echo "UNEXPECTED: the AppRole play failed" >&2
  cat "$WORK/approle.txt"
  exit 1
fi
grep -q 'AppRole read the expected secret: True' "$WORK/approle.txt" \
  || { echo "UNEXPECTED: the AppRole did not read the secret" >&2; cat "$WORK/approle.txt"; exit 1; }
echo "OK 8 - AppRole machine identity read the scoped secret"

echo
echo "ALL CHECKS PASSED"
