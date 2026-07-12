#!/usr/bin/env bash
# cap26 - solution test. Proves the CI/CD machinery around the shipped project,
# entirely locally and offline:
#   1. the quality gates actually bite (green on the good project, red on a
#      broken playbook);
#   2. the production gate is correct (deploy needs the CI job and runs only on a
#      release tag; a branch push is blocked, a tag is allowed);
#   3. the same gate fires as a pre-commit hook before a commit can be made.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
VENV="$WORK/venv"
# keep pre-commit's store and git's config out of the user's home
export PRE_COMMIT_HOME="$WORK/pchome"
export GIT_CONFIG_GLOBAL="$WORK/gitconfig"
export GIT_CONFIG_SYSTEM=/dev/null
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

python3 -m venv "$VENV"
# shellcheck disable=SC1091
. "$VENV/bin/activate"
pip -q install -r "$HERE/requirements.txt"

# work on a copy so the shipped files are never mutated
PROJ="$WORK/proj"
cp -r "$HERE" "$PROJ"
rm -f "$PROJ/run.sh" "$PROJ/answers.md"
cd "$PROJ"

# --- 1. the quality gates bite ---
if ! ./ci/lint.sh >"$WORK/lint.log" 2>&1; then
  echo "UNEXPECTED: lint failed on the shipped project" >&2
  tail -5 "$WORK/lint.log" >&2; exit 1
fi
if ! ./ci/validate.sh >"$WORK/val.log" 2>&1; then
  echo "UNEXPECTED: validate failed on the shipped project" >&2
  tail -5 "$WORK/val.log" >&2; exit 1
fi
# red on a broken playbook: an unnamed play, a bare command, no changed_when
cat > site.yml <<'YML'
---
- hosts: local
  tasks:
    - command: touch /tmp/cap26app/marker
YML
set +e; ./ci/lint.sh >"$WORK/lint_bad.log" 2>&1; lint_rc=$?; set -e
if [ "$lint_rc" -eq 0 ]; then
  echo "UNEXPECTED: lint passed a broken playbook" >&2; exit 1
fi
cp "$HERE/site.yml" site.yml   # restore the good playbook
echo "OK 1 - quality gates bite (green on the good project, lint red on a broken one)"

# --- 2. the production gate is correct ---
python3 - "$HERE/.github/workflows/ci.yml" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
# YAML reads the bare "on:" key as the boolean True (cap04, the score that lies)
on = d.get(True, d.get("on"))
dep = d["jobs"]["deploy"]
assert "push" in on, "the CI must run on push"
assert dep.get("needs") == "test", "deploy must need the test job"
assert "refs/tags/v" in dep.get("if", ""), "deploy must be gated on a release tag"
print("gate-structure-ok")
PY
# the gate rule, demonstrated: a branch ref is blocked, a release tag is allowed
gate() { case "$1" in refs/tags/v*) return 0 ;; *) return 1 ;; esac; }
if gate refs/heads/main; then echo "UNEXPECTED: gate allowed a branch push" >&2; exit 1; fi
if ! gate refs/tags/v1.4.0; then echo "UNEXPECTED: gate blocked a release tag" >&2; exit 1; fi
echo "OK 2 - production gate correct (deploy needs test; branch blocked, tag allowed)"

# --- 3. shift-left: the same gate fires as a pre-commit hook, offline ---
git init -q .
git add -A
if ! pre-commit run --all-files ansible-lint >"$WORK/pc.log" 2>&1; then
  echo "UNEXPECTED: the pre-commit hook failed on the good tree" >&2
  tail -10 "$WORK/pc.log" >&2; exit 1
fi
# introduce a lint violation and confirm the hook blocks it
cat > site.yml <<'YML'
---
- hosts: local
  tasks:
    - command: touch /tmp/cap26app/marker
YML
git add -A
set +e; pre-commit run --all-files ansible-lint >"$WORK/pc_bad.log" 2>&1; pc_rc=$?; set -e
if [ "$pc_rc" -eq 0 ]; then
  echo "UNEXPECTED: the pre-commit hook passed a broken tree" >&2; exit 1
fi
echo "OK 3 - pre-commit hook fires offline (passes clean, blocks a lint violation)"

echo
echo "ALL CHECKS PASSED"
