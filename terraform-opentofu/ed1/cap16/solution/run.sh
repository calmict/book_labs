#!/usr/bin/env bash
set -euo pipefail

# Chapter 16 solution — functions, for expressions and console, end to end:
#   1. the bench: tofu console evaluates functions with no state, no apply
#      (lower/trimspace/split give predictable values);
#   2. the assembly line: a list comprehension + toset() cleans and dedups
#      4 raw hosts into 3 identities, which drive a for_each of containers;
#   3. the derived map and the filter: a map comprehension gives host->role,
#      a trailing if keeps only the web tier;
#   4. the artifact: jsonencode + sort + tolist serialise it all to a file.
#
# Needs a running Docker engine (no host ports). Runs in a throwaway temp
# dir; guaranteed cleanup (destroy + rm) on exit.

DIR=$(cd "$(dirname "$0")" && pwd)

if command -v tofu >/dev/null 2>&1; then
  TF=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF=terraform
else
  echo "ERROR: neither tofu nor terraform found (see SETUP.md)" >&2
  exit 1
fi
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found" >&2; exit 1; }

WORK=$(mktemp -d)
cleanup() {
  (cd "$WORK" 2>/dev/null && "$TF" destroy -input=false -auto-approve >/dev/null 2>&1) || true
  docker rm -f cap16-web-01 cap16-api-02 cap16-db-03 >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

cp "$DIR/main.tf" "$WORK/"
cd "$WORK"
"$TF" init -input=false >/dev/null

echo "== 1. The bench: functions, no state touched =="
echo 'lower(trimspace("  Web-01 "))' | "$TF" console | grep -q '"web-01"'
echo "  lower(trimspace(\"  Web-01 \"))  ->  \"web-01\""
echo 'split("-", "web-01")[0]' | "$TF" console | grep -q '"web"'
echo "  split(\"-\", \"web-01\")[0]      ->  \"web\""
echo "  (a plain plan/apply was never run — the bench evaluates in place)"
echo

echo "== 2. The assembly line: 4 raw hosts, deduped, become containers =="
"$TF" apply -input=false -auto-approve >/dev/null
"$TF" state list | grep -E 'docker_container.host\[' | sed 's/^/  address: /'
n=$("$TF" state list | grep -cE 'docker_container.host\[')
test "$n" -eq 3
echo "  4 raw hosts in, ${n} containers out (Web-01 / web-01 deduped in the toset)"
echo

echo "== 3. The derived map and the filter =="
echo 'local.host_roles' | "$TF" console | grep -E '"(web-01|api-02|db-03)"' | sed 's/^ *//;s/^/  role: /'
echo 'local.web_hosts' | "$TF" console | grep -q '"web-01"'
echo "  web_hosts (if role == web) -> only web-01 passes"
echo

echo "== 4. The artifact: functions producing a file =="
grep -q '"hosts":\["api-02","db-03","web-01"\]' inventory.json
grep -q '"web-01":"web"' inventory.json
grep -q '"web":\["web-01"\]' inventory.json
sed 's/^/  inventory.json: /' inventory.json
echo
echo "  (jsonencode + sort + tolist: the transformations, serialised)"
echo

echo "=== functions clean, for expressions reshape, console proves it before a single apply ==="
