#!/usr/bin/env bash
# cap09 - solution test. Builds the image from the fundamental Dockerfile and
# checks it behaves as declared: COPY put greet.sh in the image at WORKDIR /app,
# ENV set GREETING in the config, and CMD makes the default command run the app
# and print "ciao mondo". Throwaway image, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TAG="cap09-$$"
cleanup() { docker rmi -f "$TAG" >/dev/null 2>&1 || true; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

docker build -q -t "$TAG" "$HERE" >/dev/null

# 1. COPY + WORKDIR: greet.sh is in the image at /app, and WorkingDir is /app
if ! docker run --rm "$TAG" sh -c 'test -f /app/greet.sh'; then
  echo "UNEXPECTED: greet.sh is not at /app/greet.sh in the image" >&2; exit 1
fi
workdir=$(docker image inspect -f '{{.Config.WorkingDir}}' "$TAG")
if [ "$workdir" != "/app" ]; then
  echo "UNEXPECTED: WorkingDir is '$workdir', expected /app" >&2; exit 1
fi
echo "OK 1 - COPY + WORKDIR: greet.sh is at /app (WorkingDir=$workdir)"

# 2. ENV: the image config carries GREETING=ciao
if [ "$(docker image inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$TAG" | grep -c '^GREETING=ciao')" != "1" ]; then
  echo "UNEXPECTED: GREETING=ciao is not set in the image config" >&2; exit 1
fi
echo "OK 2 - ENV: GREETING=ciao is set in the image config"

# 3. CMD: running with no arguments runs greet.sh, which uses the ENV
out=$(docker run --rm "$TAG")
if [ "$out" != "ciao mondo" ]; then
  echo "UNEXPECTED: default command printed '$out', expected 'ciao mondo'" >&2; exit 1
fi
echo "OK 3 - CMD: the default command runs greet.sh and prints \"$out\""

echo
echo "ALL CHECKS PASSED"
