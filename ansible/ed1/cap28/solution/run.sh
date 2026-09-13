#!/usr/bin/env bash
# cap28 - solution test. The pre-import gate for an AWX / Automation Platform object
# graph defined as code: no AWX needed, all local and offline. It syntax-checks the
# project's real playbooks, validates the completed object graph (references resolve,
# secrets linked through input sources not stored, RBAC scoped, workflow a valid DAG), and proves each
# check bites by feeding the validator a broken graph.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
VENV="$WORK/venv"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# ansible-core 2.19 needs Python >= 3.11 on the control node: take the first
# interpreter that has it (plain python3 on recent systems).
PY=""
for cand in python3.13 python3.12 python3.11 python3; do
  if command -v "$cand" >/dev/null 2>&1 \
    && "$cand" -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then
    PY=$cand
    break
  fi
done
[ -n "$PY" ] || { echo "ERROR: Python >= 3.11 not found (ansible-core 2.19 needs it)" >&2; exit 1; }
"$PY" -m venv "$VENV"
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
expect_reject() {  # $1 = mutated objects file, $2 = label, $3 = expected reason
  if python3 "$HERE/validate.py" "$1" "$PROJ" >"$WORK/r.out" 2>&1; then
    echo "UNEXPECTED: the validator accepted a graph with $2" >&2; exit 1
  fi
  if ! grep -q "$3" "$WORK/r.out"; then
    echo "UNEXPECTED: the graph with $2 was rejected for another reason:" >&2
    cat "$WORK/r.out" >&2; exit 1
  fi
}

mutate_secret() {  # $1 = mode, $2 = output file
  python3 - "$OBJ" "$2" "$1" <<'PY'
import sys
import yaml
d = yaml.safe_load(open(sys.argv[1]))
creds = {c["name"]: c for c in d["credentials"]}
mode = sys.argv[3]
if mode == "plaintext":
    creds["deploy-ssh"]["inputs"]["ssh_key_data"] = "hunter2"
elif mode == "template":
    d["credential_input_sources"] = []
    creds["deploy-ssh"]["inputs"]["ssh_key_data"] = (
        "{{ lookup('community.hashi_vault.vault_kv2_get', 'ansible/deploy-ssh').secret.ssh_key }}")
elif mode == "not-external":
    d["credential_input_sources"][0]["source_credential"] = "deploy-ssh"
yaml.safe_dump(d, open(sys.argv[2], "w"))
PY
}

sed 's/inventory: production/inventory: staging/' "$OBJ" > "$WORK/m1.yml"
expect_reject "$WORK/m1.yml" "a dangling inventory reference" "unknown or missing inventory"

sed 's/role: execute/role: admin/' "$OBJ" > "$WORK/m2.yml"
expect_reject "$WORK/m2.yml" "an over-broad RBAC grant" "over-broad role"

mutate_secret plaintext "$WORK/m3.yml"
expect_reject "$WORK/m3.yml" "a plaintext secret" "stores 'ssh_key_data' in the graph"

mutate_secret template "$WORK/m5.yml"
expect_reject "$WORK/m5.yml" "a secret written as a lookup expression" "holds a template expression"

mutate_secret not-external "$WORK/m6.yml"
expect_reject "$WORK/m6.yml" "an input source that is not a secret manager" "not an external secret-manager credential"

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
expect_reject "$WORK/m4.yml" "a workflow with no failure path to rollback" "no failure path"

echo "OK 3 - every broken graph is rejected (dangling ref, broad RBAC, plaintext secret, lookup expression, non-external source, no rollback path)"

echo
echo "ALL CHECKS PASSED"
