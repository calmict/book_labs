#!/usr/bin/env bash
# cap09 - solution test. Builds the image from the fundamental Dockerfile and
# checks it behaves as declared: COPY put greet.sh in the image at WORKDIR /app,
# ENV set GREETING in the config, and CMD makes the default command run the app
# and print "ciao mondo". It also compares separate and concatenated RUN layers,
# then proves that an ARG value remains in history but not in the runtime
# environment. Throwaway images, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TAG="cap09-$$"
LAYERS_SEPARATE_TAG="cap09-layers-separate-$$"
LAYERS_JOINED_TAG="cap09-layers-joined-$$"
ARG_TAG="cap09-arg-$$"
cleanup() {
  docker rmi -f "$TAG" "$LAYERS_SEPARATE_TAG" "$LAYERS_JOINED_TAG" "$ARG_TAG" >/dev/null 2>&1 || true
}
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

# 4. RUN layers: deleting in a later layer keeps the payload in the image
docker build -q -f "$HERE/Dockerfile.layers" --target layers-separate -t "$LAYERS_SEPARATE_TAG" "$HERE" >/dev/null
docker build -q -f "$HERE/Dockerfile.layers" --target layers-joined -t "$LAYERS_JOINED_TAG" "$HERE" >/dev/null
separate_size=$(docker image inspect -f '{{.Size}}' "$LAYERS_SEPARATE_TAG")
joined_size=$(docker image inspect -f '{{.Size}}' "$LAYERS_JOINED_TAG")
payload_size=$((8 * 1024 * 1024))
minimum_difference=$((payload_size * 3 / 4))
difference=$((separate_size - joined_size))
if [ "$difference" -lt "$minimum_difference" ]; then
  echo "UNEXPECTED: separate RUN image is only $difference bytes larger; expected at least $minimum_difference" >&2; exit 1
fi
echo "OK 4 - RUN layers: separate=${separate_size}B joined=${joined_size}B difference=${difference}B"

# 5. ARG: the build value is visible in history, but is not a runtime ENV
secret="cap09-secret-$$"
docker build -q -f "$HERE/Dockerfile.arg" --build-arg "SECRET_TOKEN=$secret" -t "$ARG_TAG" "$HERE" >/dev/null
if ! docker history --no-trunc "$ARG_TAG" | grep -Fq "$secret"; then
  echo "UNEXPECTED: the ARG value is not visible in docker history --no-trunc" >&2; exit 1
fi
if docker run --rm "$ARG_TAG" env | grep -q '^SECRET_TOKEN='; then
  echo "UNEXPECTED: SECRET_TOKEN is present in the runtime environment" >&2; exit 1
fi
if ! docker run --rm "$TAG" env | grep -q '^GREETING=ciao$'; then
  echo "UNEXPECTED: GREETING=ciao is absent from the runtime environment" >&2; exit 1
fi
echo "OK 5 - ARG: its value is visible in history but absent at runtime; ENV remains present"

echo
echo "ALL CHECKS PASSED"
