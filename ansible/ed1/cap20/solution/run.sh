#!/usr/bin/env bash
# cap20 - solution test. Node-less: Jinja2 turns raw data into a config on the
# control node. Proves the derivations (map/select/combine) and the template
# that writes itself, including idempotence. No containers, no nodes.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

WORK=$(mktemp -d)
VENV="$WORK/venv"
export CAP20_OUT="$WORK/out"

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

python3 -m venv "$VENV"
"$VENV/bin/pip" -q install -r requirements.txt
AP="$VENV/bin/ansible-playbook"

CONF="$CAP20_OUT/app.conf"

# --- 1. first run renders the config ---
if ! "$AP" -i localhost, site.yml > "$WORK/run1.txt" 2>&1; then
  echo "UNEXPECTED: the playbook failed" >&2
  cat "$WORK/run1.txt"
  exit 1
fi
test -f "$CONF" || { echo "UNEXPECTED: app.conf was not rendered" >&2; exit 1; }
echo "OK 1 - the template rendered app.conf"

# --- 2. combine applied the overrides ---
grep -qx 'timeout = 60' "$CONF" \
  || { echo "UNEXPECTED: override timeout not applied" >&2; cat "$CONF"; exit 1; }
grep -qx 'loglevel = debug' "$CONF" \
  || { echo "UNEXPECTED: override loglevel not applied" >&2; exit 1; }
echo "OK 2 - combine merged base + overrides"

# --- 3. selectattr kept only the enabled services; web-02 excluded ---
for svc in api-01 db-01 web-01; do
  grep -q "^\[$svc\]" "$CONF" \
    || { echo "UNEXPECTED: block [$svc] is missing" >&2; cat "$CONF"; exit 1; }
done
if grep -q '^\[web-02\]' "$CONF"; then
  echo "UNEXPECTED: the disabled service web-02 was rendered" >&2
  exit 1
fi
echo "OK 3 - only enabled services rendered (web-02 excluded)"

# --- 4. the blocks are sorted by name (api < db < web) ---
la=$(grep -n '^\[api-01\]' "$CONF" | cut -d: -f1)
ld=$(grep -n '^\[db-01\]' "$CONF" | cut -d: -f1)
lw=$(grep -n '^\[web-01\]' "$CONF" | cut -d: -f1)
if [ "$la" -lt "$ld" ] && [ "$ld" -lt "$lw" ]; then
  echo "OK 4 - the service blocks are sorted by name"
else
  echo "UNEXPECTED: the service blocks are not sorted" >&2
  exit 1
fi

# --- 5. selectattr(env=prod) + map(port) produced the prod ports line ---
grep -qx '# allowed prod ports: 8080,8081,5432' "$CONF" \
  || { echo "UNEXPECTED: the prod ports line is wrong" >&2; cat "$CONF"; exit 1; }
echo "OK 5 - the prod ports line was derived from the data"

# --- 6. recursive combine kept the nested 'host' key (shallow would drop it) ---
grep -q "recursive = {'server': {'host': '0.0.0.0', 'port': 8443}, 'tls': False}" "$WORK/run1.txt" \
  || { echo "UNEXPECTED: recursive combine did not merge the nested dict" >&2; exit 1; }
echo "OK 6 - combine(recursive=true) merged the nested dict"

# --- 7. idempotence: a second run changes nothing ---
"$AP" -i localhost, site.yml > "$WORK/run2.txt" 2>&1
if ! grep -qE 'localhost[[:space:]]+: ok=[0-9]+[[:space:]]+changed=0[[:space:]]' "$WORK/run2.txt"; then
  echo "UNEXPECTED: the rerun was not idempotent" >&2
  grep 'localhost' "$WORK/run2.txt"
  exit 1
fi
echo "OK 7 - rerun is idempotent (changed=0)"

echo
echo "ALL CHECKS PASSED"
