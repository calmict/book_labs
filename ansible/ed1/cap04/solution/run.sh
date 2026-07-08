#!/usr/bin/env bash
set -euo pipefail

# Chapter 4 solution — YAML anatomy, proven with the parser Ansible uses (PyYAML):
#   1. the start config LOOKS right but is silently mis-typed (NO->False, 1.20->1.2)
#   2. the loud traps (a colon, a bad indent) fail to parse outright
#   3. the fixed config MEANS what it says (quoted) and is DRY (anchor + merge)
#   4. block scalars: literal | keeps newlines
#   5. the safety net: yamllint flags the truthy traps (if installed)
#
# Pure files, no containers. Needs python3 with PyYAML.

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found" >&2; exit 1; }
python3 -c 'import yaml' 2>/dev/null || { echo "ERROR: PyYAML not available (pip install pyyaml)" >&2; exit 1; }

DIR=$(cd "$(dirname "$0")" && pwd)
START="$DIR/../start/config.yml"
SOL="$DIR/config.yml"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "== 1. The start config LOOKS right but is silently mis-typed =="
python3 "$DIR/inspect.py" "$START" | sed 's/^/  /'
python3 - "$START" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
assert d["country"] is False, "country (NO) should have parsed as the boolean False"
assert isinstance(d["version"], float) and d["version"] == 1.2, "version (1.20) should be the float 1.2"
assert d["file_mode"] == 420, "file_mode (0644) should be the octal int 420"
assert d["window"] == 1350, "window (22:30) should be the base-60 int 1350"
print("  -> confirmed: NO->False, 1.20->1.2, 0644->420, 22:30->1350 (all the wrong type)")
PY
echo

echo "== 2. Loud traps: some mistakes the parser catches outright =="
printf 'note: value with: a colon\n' > "$TMP/colon.yml"
if python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$TMP/colon.yml" 2>/dev/null; then
  echo "  UNEXPECTED: the colon file parsed"; exit 1
fi
echo "  unquoted value with a colon -> parse error (mapping values are not allowed here)"
printf 'a: 1\n  b: 2\n' > "$TMP/indent.yml"
if python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$TMP/indent.yml" 2>/dev/null; then
  echo "  UNEXPECTED: the bad-indent file parsed"; exit 1
fi
echo "  wrong indentation -> parse error; the loud traps fail fast, the silent ones are the dangerous ones"
echo

echo "== 3. The fixed config MEANS what it says, and is DRY =="
python3 - "$SOL" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
assert d["country"] == "NO" and isinstance(d["country"], str), "country should be the string NO"
assert d["version"] == "1.20", "version should be the string 1.20"
assert d["file_mode"] == "0644", "file_mode should be the string 0644"
assert d["window"] == "22:30", "window should be the string 22:30"
web, db = d["hosts"]["web"], d["hosts"]["db"]
assert web["retries"] == 3 and web["timeout"] == 30 and web["healthcheck"] == "/healthz", "web should inherit &defaults"
assert web["role"] == "frontend", "web keeps its own role"
assert db["retries"] == 3 and db["timeout"] == 60, "db inherits retries but overrides timeout"
print("  -> quoted values keep their meaning; web/db share &defaults via <<, db overrides only timeout")
PY
echo

echo "== 4. Block scalars: literal | keeps newlines =="
python3 - "$SOL" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
motd = d["motd"]
assert "\n" in motd, "the literal block should keep its newlines"
print("  motd (literal |):", repr(motd))
PY
echo

echo "== 5. The safety net: yamllint flags the truthy traps =="
if command -v yamllint >/dev/null 2>&1; then
  yamllint "$START" 2>&1 | grep -i truthy | head -3 | sed 's/^/  /' || true
  echo "  (yamllint shouts on no/NO/off before Ansible can misread them)"
else
  echo "  yamllint not installed here; in CI it runs and flags no/NO/off as truthy -- the net that catches these"
fi
echo

echo "=== YAML anatomy: unquoted values can lie; quote the ambiguous ones, DRY with anchors, lint as the net ==="
