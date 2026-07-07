#!/usr/bin/env bash
set -euo pipefail

# Chapter 20 solution — the twins and the lock, end to end:
#   1. the 95%: the SAME config runs identically on tofu and terraform;
#   2. the secret in plain text: an unencrypted state holds random_password's
#      material in the clear (chapter 11's open problem);
#   3. the 5%: OpenTofu's native state encryption (config via TF_ENCRYPTION,
#      passphrase never in a file) turns the state into an encrypted envelope;
#   4. the boundary: without the passphrase tofu cannot read it, and terraform
#      cannot read an encrypted state at all (Unsupported state file format).
#
# No Docker, no ports (the random provider makes nothing external). Runs in a
# throwaway temp dir; guaranteed cleanup on exit. An ephemeral passphrase is
# generated at runtime — nothing secret is committed.

if command -v tofu >/dev/null 2>&1; then
  TF=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF=terraform
else
  echo "ERROR: neither tofu nor terraform found (see SETUP.md)" >&2
  exit 1
fi

DIR=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

echo "== 1. The 95%: the same config, two binaries =="
mkdir -p "$WORK/twins"
cd "$WORK/twins"
cat >main.tf <<'EOF'
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
resource "random_pet" "name" {
  length = 2
}
output "pet" {
  value = random_pet.name.id
}
EOF
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
echo "  tofu:      $("$TF" output -raw pet)"
if command -v terraform >/dev/null 2>&1; then
  rm -rf .terraform* terraform.tfstate*
  terraform init -input=false >/dev/null
  terraform apply -input=false -auto-approve >/dev/null
  echo "  terraform: $(terraform output -raw pet)"
  echo "  (same HCL, same provider, not a line changed — the 95%)"
else
  echo "  terraform: not installed — take the twin on faith (the 95%)"
fi
echo

echo "== 2. The secret in plain text (chapter 11) =="
mkdir -p "$WORK/enc"
cp "$DIR/main.tf" "$WORK/enc/main.tf"
cd "$WORK/enc"
"$TF" init -input=false >/dev/null
"$TF" apply -input=false -auto-approve >/dev/null
test "$(grep -c '"random_password"' terraform.tfstate)" -gt 0
echo "  unencrypted state contains the resource in the clear:"
grep -oE '"(random_password|result|bcrypt_hash)"' terraform.tfstate | sort -u | sed 's/^/    /'
echo

echo "== 3. The 5%: native state encryption (passphrase from the environment) =="
"$TF" destroy -input=false -auto-approve >/dev/null
rm -f terraform.tfstate*
PASS=$(openssl rand -hex 20)
export TF_ENCRYPTION="key_provider \"pbkdf2\" \"k\" { passphrase = \"${PASS}\" }
method \"aes_gcm\" \"m\" { keys = key_provider.pbkdf2.k }
state { method = method.aes_gcm.m }"
"$TF" apply -input=false -auto-approve >/dev/null
echo "  envelope head: $(head -c 64 terraform.tfstate)..."
test "$(grep -c '"random_password"' terraform.tfstate)" -eq 0
echo "  no plaintext secret: grep '\"random_password\"' -> 0 matches (encrypted)"
echo

echo "== 4. The boundary: no passphrase, no read =="
echo "  with the passphrase, tofu reads it: $("$TF" state list | tr '\n' ' ')"
unset TF_ENCRYPTION
# strip ANSI colour codes the CLIs put in their error output
strip() { sed -E 's/\x1b\[[0-9;]*m//g'; }
"$TF" state list >noread.out 2>&1 && { echo "unexpected: read without passphrase" >&2; exit 1; }
grep -iE 'encrypted and can not be read' noread.out | strip | sed 's/^.*Failed/Failed/;s/^/  no passphrase -> /' | head -1
if command -v terraform >/dev/null 2>&1; then
  terraform init -input=false >/dev/null 2>&1 || true
  terraform show -no-color >tfread.out 2>&1 && { echo "unexpected: terraform read the encrypted state" >&2; exit 1; }
  grep -iE 'Unsupported state file format' tfread.out | strip | sed -E 's/^.*(Unsupported state file format).*/\1/;s/^/  terraform -> /' | head -1
else
  echo "  terraform: not installed — the twin's failure you read in the manual"
fi
echo

echo "=== 95% identical, 5% decisive: the encrypted notebook is a door only OpenTofu can open ==="
