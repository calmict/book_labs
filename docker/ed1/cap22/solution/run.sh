#!/usr/bin/env bash
# cap22 - solution test. Brings up the Compose app and checks: an environment
# variable takes its value from a .env file; a secret is mounted as a file and does
# not leak into the environment; .env interpolates without injecting while env_file
# injects; environment beats env_file; and the process shell beats .env during
# interpolation. Supporting files are generated in a temp directory. Unique project
# name, torn down at the end, no restart, no privileges.
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
printf 'DOTENV_ONLY=from-dotenv\nSHELL_PRIORITY=from-dotenv\n' >> "$WORK/.env"
printf 'ENV_FILE_ONLY=from-env-file\nSOURCE_PRIORITY=from-env-file\n' > "$WORK/app.env"
printf 's3cr3t-pw' > "$WORK/db_password.txt"

SHELL_PRIORITY=from-shell dc up -d >/dev/null 2>&1

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

# 4. .env interpolates values but does not inject unreferenced keys; env_file does
dotenv_only=$(dc exec -T app printenv | sed -n 's/^DOTENV_ONLY=//p')
env_file_only=$(dc exec -T app printenv ENV_FILE_ONLY)
if [ -n "$dotenv_only" ]; then
  echo "UNEXPECTED: DOTENV_ONLY was injected from .env as '$dotenv_only'" >&2; exit 1
fi
if [ "$env_file_only" != "from-env-file" ]; then
  echo "UNEXPECTED: ENV_FILE_ONLY is '$env_file_only', expected 'from-env-file'" >&2; exit 1
fi
echo "OK 4 - .env only interpolates; env_file injects into the container"

# 5. environment beats env_file; the process shell beats .env for interpolation
source_priority=$(dc exec -T app printenv SOURCE_PRIORITY)
shell_priority=$(dc exec -T app printenv SHELL_PRIORITY)
if [ "$source_priority" != "from-environment" ]; then
  echo "UNEXPECTED: SOURCE_PRIORITY is '$source_priority', expected 'from-environment'" >&2; exit 1
fi
if [ "$shell_priority" != "from-shell" ]; then
  echo "UNEXPECTED: SHELL_PRIORITY is '$shell_priority', expected 'from-shell'" >&2; exit 1
fi
echo "OK 5 - environment beats env_file; the process shell beats .env interpolation"

echo
echo "ALL CHECKS PASSED"
