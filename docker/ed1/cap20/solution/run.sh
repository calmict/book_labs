#!/usr/bin/env bash
# cap20 - solution test. Brings up the two-service Compose application and checks:
# both services are running; web reaches db by service name (the app network
# Compose creates, with its embedded DNS); and the file declares web depends_on db.
# Unique project name, torn down at the end, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
PROJ="cap20-$$"
COMPOSE="$HERE/compose.yaml"
dc() { docker compose -p "$PROJ" -f "$COMPOSE" "$@"; }
cleanup() { dc down -v >/dev/null 2>&1 || true; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: docker compose plugin not found (see SETUP.md)" >&2; exit 1; }

dc up -d >/dev/null 2>&1

# 1. both services are running
running=$(docker ps -q --filter "label=com.docker.compose.project=$PROJ" | grep -c . || true)
if [ "$running" != "2" ]; then
  echo "UNEXPECTED: expected 2 running services, got $running" >&2; dc ps >&2; exit 1
fi
echo "OK 1 - both services are up (db, web)"

# 2. web reaches db by service name (Compose app network + embedded DNS)
resolve=$(dc exec -T web sh -c 'ping -c1 -w2 db >/dev/null 2>&1 && echo OK || echo FAIL')
if [ "$resolve" != "OK" ]; then
  echo "UNEXPECTED: web did not reach db by name (resolve=$resolve)" >&2; exit 1
fi
echo "OK 2 - web reaches db by service name (Compose network DNS)"

# 3. the file declares web depends_on db
if ! dc config 2>/dev/null | grep -A2 'depends_on:' | grep -q 'db:'; then
  echo "UNEXPECTED: web does not declare depends_on db" >&2; exit 1
fi
echo "OK 3 - web declares depends_on db (ordered startup, one declarative file)"

echo
echo "ALL CHECKS PASSED"
