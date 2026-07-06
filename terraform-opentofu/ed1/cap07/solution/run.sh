#!/usr/bin/env bash
set -euo pipefail

# Chapter 7 solution — the version register, end to end:
#   0. the closed gate: required_version "< 1.0.0" makes init refuse;
#   1. the exact pin: 3.5.1 installed, the lock file born (version,
#      constraint, hashes);
#   2. the fence widens (~> 3.5), the choice stays: init reuses 3.5.1
#      from the lock;
#   3. the deliberate gesture: init -upgrade moves to the latest 3.x and
#      the lock's diff shows it;
#   4. the conflict: exact pin vs upgraded lock — init stops with the
#      error that names the way out;
#   5. the July colleague: no lock, same code, newer translator.
#
# Runs in a throwaway temp dir; guaranteed cleanup (destroy + rm) on exit.

if command -v tofu >/dev/null 2>&1; then
  TF=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF=terraform
else
  echo "ERROR: neither tofu nor terraform found (see SETUP.md)" >&2
  exit 1
fi

WORK=$(mktemp -d)
cleanup() {
  (cd "$WORK" 2>/dev/null && "$TF" destroy -input=false -auto-approve >/dev/null 2>&1) || true
  rm -rf "$WORK"
}
trap cleanup EXIT

cd "$WORK"
# The exercise's starting state: gate broken by design, provider pinned.
cat > main.tf <<'EOF'
terraform {
  required_version = "< 1.0.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

resource "random_pet" "mascot" {
  length = 2
}

output "mascot" {
  value = random_pet.mascot.id
}
EOF

echo "== 0. The closed gate =="
rc=0
"$TF" init -input=false -no-color >gate.out 2>&1 || rc=$?
test "$rc" -ne 0
grep -E 'Unsupported (OpenTofu|Terraform) Core version' gate.out | head -1 | sed 's/^/  init refused: /'
echo "  (the gate protects the team from the colleague with the ancient binary)"
sed -i 's/required_version = "< 1.0.0"/required_version = ">= 1.6.0"/' main.tf
echo

echo "== 1. The exact pin, and the register's birth =="
"$TF" init -input=false -no-color | grep -E 'Installing hashicorp/random' | sed 's/^- /  /'
test -f .terraform.lock.hcl
grep -E '^  (version|constraints)' .terraform.lock.hcl | sed 's/^ */  lock says: /'
grep -Ec '"(h1|zh):' .terraform.lock.hcl | sed 's/^/  fingerprints (hashes) recorded: /'
"$TF" apply -input=false -auto-approve >/dev/null
echo "  mascot applied: $("$TF" output -raw mascot)"
echo

echo "== 2. The fence widens, the choice stays =="
sed -i 's/version = "3.5.1"/version = "~> 3.5"/' main.tf
"$TF" init -input=false -no-color | grep -E 'Reusing previous version' | sed 's/^- /  /'
grep -E '^  version' .terraform.lock.hcl | sed 's/^ */  still: /'
grep -qE '^  version += +"3\.5\.1"' .terraform.lock.hcl
echo "  (the fence allows 3.9.x, the lock keeps 3.5.1: nothing moves behind your back)"
echo

echo "== 3. The deliberate gesture: init -upgrade =="
cp .terraform.lock.hcl lock.before
"$TF" init -input=false -no-color -upgrade | grep -E 'Installing hashicorp/random' | sed 's/^- /  /'
diff lock.before .terraform.lock.hcl | grep -E '^[<>] +version' | sed 's/^/  lock diff: /' || true
new_version=$(grep -E '^  version' .terraform.lock.hcl | sed 's/[^0-9.]//g')
test "$new_version" != "3.5.1"
echo "  (moved WITHIN the fence, deliberately; in a team this diff goes into a commit)"
echo

echo "== 4. The conflict: exact pin vs upgraded lock =="
sed -i 's/version = "~> 3.5"/version = "3.5.1"/' main.tf
rc=0
"$TF" init -input=false -no-color >conflict.out 2>&1 || rc=$?
test "$rc" -ne 0
# (the error message wraps mid-sentence: grep single-line fragments)
grep -E 'does not match' conflict.out | head -1 | sed 's/^/  init says: ... /'
grep -E 'init -upgrade' conflict.out | head -1 | sed 's/^ */  the way out is named: ... /'
echo "  (no silent downgrade, no silent upgrade: the tool refuses to choose alone)"
sed -i 's/version = "3.5.1"/version = "~> 3.5"/' main.tf
echo

echo "== 5. The July colleague: same code, no register =="
rm -f .terraform.lock.hcl
rm -rf .terraform
"$TF" init -input=false -no-color | grep -E 'Installing hashicorp/random' | sed 's/^- /  /'
july=$(grep -E '^  version' .terraform.lock.hcl | sed 's/[^0-9.]//g')
test "$july" != "3.5.1"
echo "  January had 3.5.1, July got ${july}: drift on the tools, not the servers."
echo "  The single remedy: COMMIT the lock file (this exercise repo gitignores it"
echo "  only so these experiments stay repeatable)."
echo

echo "=== the constraint is the fence, the lock is the choice — and choices are committed ==="
