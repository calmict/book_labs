#!/usr/bin/env bash
# cap21 - solution test. Brings up the Compose app with a readiness gate and checks:
# db has a healthcheck and reaches "healthy"; web is running and depends on db with
# condition service_healthy; and the gate held - "docker compose up" waited for db's
# readiness (a few seconds) before starting web, instead of returning at once.
# Unique project name, torn down at the end, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
PROJ="cap21-$$"
COMPOSE="$HERE/compose.yaml"
dc() { docker compose -p "$PROJ" -f "$COMPOSE" "$@"; }
cleanup() { dc down -v >/dev/null 2>&1 || true; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: docker compose plugin not found (see SETUP.md)" >&2; exit 1; }

# the readiness gate makes 'up -d' block until db is healthy, so we time it
t0=$(date +%s)
dc up -d >/dev/null 2>&1
t1=$(date +%s)
up_seconds=$((t1 - t0))

# 1. db has a healthcheck and reached the healthy state
db_health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$(dc ps -q db)")
if [ "$db_health" != "healthy" ]; then
  echo "UNEXPECTED: db is not healthy (status=$db_health)" >&2; exit 1
fi
echo "OK 1 - db has a healthcheck and is healthy"

# 2. web is running and waits for db to be healthy (condition: service_healthy)
web_running=$(docker inspect -f '{{.State.Running}}' "$(dc ps -q web)")
if [ "$web_running" != "true" ] || ! dc config 2>/dev/null | grep -q 'service_healthy'; then
  echo "UNEXPECTED: web not running, or it does not wait for db healthy (running=$web_running)" >&2; exit 1
fi
echo "OK 2 - web is up and waits for db to be healthy (condition: service_healthy)"

# 3. the gate held: up waited for db's readiness (~4s+) before starting web
if [ "$up_seconds" -lt 3 ]; then
  echo "UNEXPECTED: up returned in ${up_seconds}s - the readiness gate did not delay web" >&2; exit 1
fi
echo "OK 3 - the readiness gate held: 'up' waited ${up_seconds}s for db to be healthy"

echo
echo "ALL CHECKS PASSED"
