#!/usr/bin/env bash
# cap28 - solution test. The pre-import gate for an AWX / Automation Platform object
# graph defined as code: no AWX needed, all local and offline. It syntax-checks the
# project's real playbooks, validates the completed object graph (references resolve,
# secrets referenced not stored, RBAC scoped, workflow a valid DAG), and proves each
# check bites by feeding the validator a broken graph.
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

OBJ="$HERE/platform/objects.yml"
PROJ="$HERE/project"

# --- 1. the project's playbooks are real and well formed ---
for pb in "$PROJ"/*.yml; do
  if ! ansible-playbook --syntax-check "$pb" >/dev/null 2>&1; then
    echo "UNEXPECTED: project playbook $(basename "$pb") failed syntax-check" >&2; exit 1
  fi
done
echo "OK 1 - the project's playbooks (deploy, smoke, rollback) syntax-check"

# --- 2. the completed object graph is valid and safe to import ---
if ! python3 "$HERE/validate.py" "$OBJ" "$PROJ" >"$WORK/v.out" 2>&1; then
  echo "UNEXPECTED: the validator rejected the solution graph" >&2
  cat "$WORK/v.out" >&2; exit 1
fi
echo "OK 2 - $(cat "$WORK/v.out")"

# --- 3. the checks bite: each broken graph is rejected ---
expect_reject() {  # $1 = mutated objects file, $2 = label
  if python3 "$HERE/validate.py" "$1" "$PROJ" >/dev/null 2>&1; then
    echo "UNEXPECTED: the validator accepted a graph with $2" >&2; exit 1
  fi
}

sed 's/inventory: production/inventory: staging/' "$OBJ" > "$WORK/m1.yml"
expect_reject "$WORK/m1.yml" "a dangling inventory reference"

sed 's/role: execute/role: admin/' "$OBJ" > "$WORK/m2.yml"
expect_reject "$WORK/m2.yml" "an over-broad RBAC grant"

sed 's|secret:.*|secret: hunter2|' "$OBJ" > "$WORK/m3.yml"
expect_reject "$WORK/m3.yml" "a plaintext secret"

python3 - "$OBJ" "$WORK/m4.yml" <<'PY'
import sys
import yaml
d = yaml.safe_load(open(sys.argv[1]))
for n in d["workflows"][0]["nodes"]:
    failn = n.pop("failure_nodes", None)
    if failn:
        n["success_nodes"] = sorted(set((n.get("success_nodes") or []) + failn))
yaml.safe_dump(d, open(sys.argv[2], "w"))
PY
expect_reject "$WORK/m4.yml" "a workflow with no failure path to rollback"

echo "OK 3 - every broken graph is rejected (dangling ref, broad RBAC, plaintext secret, no rollback path)"

echo
echo "ALL CHECKS PASSED"
