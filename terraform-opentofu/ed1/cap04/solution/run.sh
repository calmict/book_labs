#!/usr/bin/env bash
set -euo pipefail

# Chapter 4 solution — the invisible foreman, end to end:
#   0. three unlinked 5s floors: the apply takes ~5s (parallel crews);
#   1. the chained tower (this folder's main.tf): ~15s, one floor at a time,
#      plus the certificate waiting on the whole tower via depends_on;
#   2. tofu graph: the edges, in the flesh;
#   3. the demolition: same graph, walked backwards;
#   4. the forbidden cycle: rejected by validate, before touching reality.
#
# Runs in a throwaway temp dir; guaranteed cleanup (destroy + rm) on exit.
# Works with tofu or terraform.

DIR=$(cd "$(dirname "$0")" && pwd)

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
# The unchained starting model: same three floors, no edges between them.
cat > main.tf <<'EOF'
terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "time_sleep" "floor_1" {
  create_duration = "5s"
}

resource "time_sleep" "floor_2" {
  create_duration = "5s"
}

resource "time_sleep" "floor_3" {
  create_duration = "5s"
}
EOF

echo "== 0. The floating tower: three 5s floors, no edges =="
"$TF" init -input=false >/dev/null
t0=$(date +%s)
"$TF" apply -input=false -auto-approve >/dev/null
t1=$(date +%s)
par=$((t1 - t0))
echo "  apply took ${par}s (three crews in parallel, not 15s)"
test "$par" -lt 12
"$TF" destroy -input=false -auto-approve >/dev/null
echo

echo "== 1. The chained tower: references + depends_on =="
cp "$DIR/main.tf" main.tf
t0=$(date +%s)
"$TF" apply -input=false -auto-approve -no-color > apply.out
t1=$(date +%s)
seq=$((t1 - t0))
echo "  apply took ${seq}s (one floor at a time: the edges changed the schedule)"
test "$seq" -ge 14
grep -E 'Creation complete' apply.out | sed 's/ \[id=.*//' | sed 's/^/    /'
echo

echo "== 2. The graph, in the flesh =="
"$TF" graph > graph.out
grep -E 'floor_2.*->.*floor_1' graph.out | head -1 | sed 's/^[[:space:]]*/  /'
grep -E 'floor_3.*->.*floor_2' graph.out | head -1 | sed 's/^[[:space:]]*/  /'
grep -E 'certificate.*->.*floor_3' graph.out | head -1 | sed 's/^[[:space:]]*/  /'
echo "  (read the arrow as: depends on — it points at what must exist first)"
echo

echo "== 3. The demolition: the same graph, walked backwards =="
"$TF" destroy -input=false -auto-approve -no-color > destroy.out
grep -E 'Destroying\.\.\.' destroy.out | sed 's/: Destroying.*//' | sed 's/^/    /'
first=$(grep -E 'Destroying\.\.\.' destroy.out | head -1)
last=$(grep -E 'Destroying\.\.\.' destroy.out | tail -1)
case "$first" in *certificate*) : ;; *) echo "unexpected first: $first"; exit 1 ;; esac
case "$last" in *floor_1*) : ;; *) echo "unexpected last: $last"; exit 1 ;; esac
echo "  certificate first, floor_1 last: nobody demolishes the ground floor first"
echo

echo "== 4. The forbidden cycle: chicken and egg =="
mkdir cycle && cd cycle
cat > main.tf <<'EOF'
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "local_file" "chicken" {
  filename = "${path.module}/chicken.txt"
  content  = "born from: ${local_file.egg.id}"
}

resource "local_file" "egg" {
  filename = "${path.module}/egg.txt"
  content  = "laid by: ${local_file.chicken.id}"
}
EOF
"$TF" init -input=false >/dev/null
rc=0
"$TF" validate -no-color > validate.out 2>&1 || rc=$?
test "$rc" -ne 0
grep -E 'Cycle' validate.out | head -1 | sed 's/^/  validate says: /'
echo "  (caught before touching reality: the graph is built from code alone)"
cd "$WORK"
echo

echo "=== no order was ever written: the references drew the graph, the graph drew the schedule ==="
