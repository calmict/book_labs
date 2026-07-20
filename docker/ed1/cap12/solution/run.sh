#!/usr/bin/env bash
# cap12 - solution test. Builds the production image and checks it runs as a
# non-root user (uid != 0), that the user is declared in the image config (USER),
# and that least privilege holds: the user can write its own /app but is denied on
# the root-owned /. Throwaway image, no restart, no privileges on the host.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TAG="cap12-$$"
cleanup() { docker rmi -f "$TAG" >/dev/null 2>&1 || true; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

docker build -q -t "$TAG" "$HERE" >/dev/null

# 1. the container runs as non-root (uid != 0)
uid=$(docker run --rm "$TAG" id -u)
if [ "$uid" = "0" ]; then
  echo "UNEXPECTED: the container runs as root (uid=0)" >&2; exit 1
fi
echo "OK 1 - runs as non-root (uid=$uid)"

# 2. the user is baked into the image config
user=$(docker image inspect -f '{{.Config.User}}' "$TAG")
if [ "$user" != "appuser" ]; then
  echo "UNEXPECTED: Config.User is '$user', expected 'appuser'" >&2; exit 1
fi
echo "OK 2 - the non-root user is declared in the image (USER=$user)"

# 3. least privilege: can write its own /app, denied on the root-owned /
if ! docker run --rm "$TAG" sh -c 'touch /app/probe'; then
  echo "UNEXPECTED: the user cannot write its own /app" >&2; exit 1
fi
if docker run --rm "$TAG" sh -c 'touch /nope' >/dev/null 2>&1; then
  echo "UNEXPECTED: the non-root user could write to / (root-owned)" >&2; exit 1
fi
echo "OK 3 - least privilege: writes its own /app, denied on root-owned /"

echo
echo "ALL CHECKS PASSED"
