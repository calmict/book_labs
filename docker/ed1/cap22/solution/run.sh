#!/usr/bin/env bash
# cap22 - solution test. Brings up the Compose app and checks: an environment
# variable takes its value from a .env file; a secret is mounted as a file at
# /run/secrets/db_password with the expected value; and the secret does NOT leak
# into the container's environment. The .env and the secret file are generated in a
# temp directory (never committed). Unique project name, torn down at the end, no
# restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
PROJ="cap22-$$"
dc() { ( cd "$WORK" && docker compose -p "$PROJ" "$@" ); }
cleanup() { dc down -v >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: docker compose plugin not found (see SETUP.md)" >&2; exit 1; }

# self-contained: the compose plus a .env and a secret file that are never committed
cp "$HERE/compose.yaml" "$WORK/compose.yaml"
printf 'APP_ENV=production\n' > "$WORK/.env"
printf 's3cr3t-pw' > "$WORK/db_password.txt"

dc up -d >/dev/null 2>&1

# 1. the env var takes its value from .env substitution
app_env=$(dc exec -T app printenv APP_ENV)
if [ "$app_env" != "production" ]; then
  echo "UNEXPECTED: APP_ENV in the container is '$app_env', expected 'production'" >&2; exit 1
fi
echo "OK 1 - env var from .env: APP_ENV=$app_env"

# 2. the secret is mounted as a file with the expected value
secret=$(dc exec -T app cat /run/secrets/db_password)
if [ "$secret" != "s3cr3t-pw" ]; then
  echo "UNEXPECTED: /run/secrets/db_password is '$secret', expected 's3cr3t-pw'" >&2; exit 1
fi
echo "OK 2 - secret mounted at /run/secrets/db_password"

# 3. the secret value does NOT leak into the environment
leak=$(dc exec -T app printenv | grep -c 's3cr3t' || true)
if [ "$leak" != "0" ]; then
  echo "UNEXPECTED: the secret value leaked into the environment ($leak match(es))" >&2; exit 1
fi
echo "OK 3 - the secret is not in the environment (a file, not an env var)"

echo
echo "ALL CHECKS PASSED"
