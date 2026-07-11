#!/usr/bin/env bash
# cap18 - solution test. Proves the whole arc of Ansible Vault:
#   - the plaintext sin of chapter 11 is gone from vars.yml;
#   - vault.yml is encrypted and decrypts to the become password;
#   - without the password Ansible refuses to decrypt;
#   - with it, the play becomes root using a secret it never prints;
#   - the run is idempotent;
#   - a single secret is encrypted inline (encrypt_string);
#   - a production secret sits under its own vault-id, and one run uses two.
#
# The lab vault passphrase is 'lab-vault-pass'; the prod vault-id passphrase is
# 'prod-pass'. Both are written to a throwaway temp dir and NEVER committed.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

WORK=$(mktemp -d)
VENV="$WORK/venv"
LABPASS="$WORK/lab.txt"
PRODPASS="$WORK/prod.txt"

cleanup() {
  ./nodes.sh down >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# --- 0. tools + node ---
python3 -m venv "$VENV"
"$VENV/bin/pip" -q install -r requirements.txt
AP="$VENV/bin/ansible-playbook"
AV="$VENV/bin/ansible-vault"

printf 'lab-vault-pass\n' > "$LABPASS"
printf 'prod-pass\n' > "$PRODPASS"

./nodes.sh up

# --- 1. the sin is gone: no plaintext password anywhere in vars.yml ---
if grep -q 'secops-pw' group_vars/web/vars.yml; then
  echo "UNEXPECTED: a plaintext password is still in vars.yml" >&2
  exit 1
fi
echo "OK 1 - no plaintext password in vars.yml"

# --- 2. vault.yml is an encrypted file that decrypts to the value ---
if ! head -1 group_vars/web/vault.yml | grep -q 'ANSIBLE_VAULT;1.1;AES256'; then
  echo "UNEXPECTED: vault.yml is not an encrypted vault file" >&2
  exit 1
fi
if ! "$AV" view --vault-password-file "$LABPASS" group_vars/web/vault.yml \
     | grep -q 'vault_become_password: secops-pw'; then
  echo "UNEXPECTED: vault.yml does not decrypt to the become password" >&2
  exit 1
fi
echo "OK 2 - vault.yml is encrypted and decrypts correctly"

# --- 3. without the vault password, decryption refuses ---
"$AP" -i inventory.ini site.yml > "$WORK/nopass.txt" 2>&1 || true
if ! grep -q 'Attempting to decrypt but no vault secrets found' "$WORK/nopass.txt"; then
  echo "UNEXPECTED: run without a vault password did not refuse as expected" >&2
  cat "$WORK/nopass.txt"
  exit 1
fi
echo "OK 3 - without the vault password, Ansible refuses to decrypt"

# --- 4. with the vault password: become root, marker + token written ---
if ! "$AP" -i inventory.ini site.yml --vault-password-file "$LABPASS" \
     > "$WORK/run1.txt" 2>&1; then
  echo "UNEXPECTED: playbook failed with the vault password" >&2
  cat "$WORK/run1.txt"
  exit 1
fi
grep -q 'became root' "$WORK/run1.txt" \
  || { echo "UNEXPECTED: did not become root" >&2; cat "$WORK/run1.txt"; exit 1; }
docker exec cap18-web1 stat -c '%U:%G' /etc/cap18-marker.txt | grep -qx 'root:root' \
  || { echo "UNEXPECTED: marker is not root-owned" >&2; exit 1; }
docker exec cap18-web1 cat /etc/myapp/token | grep -qx 'tkn-9f3a-SECRET' \
  || { echo "UNEXPECTED: the token content is wrong" >&2; exit 1; }
echo "OK 4 - became root with the vaulted password; marker + token written"

# --- 5. idempotence: a second run changes nothing ---
"$AP" -i inventory.ini site.yml --vault-password-file "$LABPASS" > "$WORK/run2.txt" 2>&1
if ! grep -qE 'web1[[:space:]]+: ok=[0-9]+[[:space:]]+changed=0[[:space:]]' "$WORK/run2.txt"; then
  echo "UNEXPECTED: the rerun was not idempotent" >&2
  grep 'web1' "$WORK/run2.txt"
  exit 1
fi
echo "OK 5 - rerun is idempotent (changed=0)"

# --- 6. encrypt_string: the token is an inline !vault block ---
if ! grep -q 'app_api_token: !vault |' group_vars/web/vars.yml; then
  echo "UNEXPECTED: app_api_token is not an inline vault block" >&2
  exit 1
fi
echo "OK 6 - app_api_token is encrypted inline (encrypt_string)"

# --- 7. vault-id: the prod secret is labelled, and one run uses two ids ---
if ! head -1 prod_secret.yml | grep -q 'ANSIBLE_VAULT;1.2;AES256;prod'; then
  echo "UNEXPECTED: prod_secret.yml is not labelled with the prod vault-id" >&2
  exit 1
fi
if ! "$AP" -i inventory.ini prod.yml \
     --vault-id "lab@$LABPASS" --vault-id "prod@$PRODPASS" \
     > "$WORK/prodrun.txt" 2>&1; then
  echo "UNEXPECTED: the prod play failed with both vault-ids" >&2
  cat "$WORK/prodrun.txt"
  exit 1
fi
docker exec cap18-web1 cat /etc/myapp/prod-db-pw | grep -qx 'prod-DB-pw' \
  || { echo "UNEXPECTED: the prod DB password was not written" >&2; exit 1; }
echo "OK 7 - prod secret guarded by its own vault-id; one run used two identities"

echo
echo "ALL CHECKS PASSED"
