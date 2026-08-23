#!/usr/bin/env bash
# cap09 - solution test. Builds the image from the fundamental Dockerfile and
# checks it behaves as declared: COPY put greet.sh in the image at WORKDIR /app,
# ENV set GREETING in the config, and CMD makes the default command run the app
# and print "ciao mondo". Then it weighs the same work written in two ways - the
# payload created and deleted in ONE RUN against Dockerfile.naive, which splits
# it in two - and shows the ARG trap: the build-time value is readable in the
# image history but does not exist inside the container. Throwaway images, no
# restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TAG="cap09-$$"
TAG_NAIVE="cap09-naive-$$"
BUILD_TOKEN="do-not-ship-this-token"
cleanup() { docker rmi -f "$TAG" "$TAG_NAIVE" >/dev/null 2>&1 || true; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

docker build -q -t "$TAG" --build-arg "BUILD_TOKEN=$BUILD_TOKEN" "$HERE" >/dev/null
docker build -q -t "$TAG_NAIVE" -f "$HERE/Dockerfile.naive" "$HERE" >/dev/null

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

# 4. Same work, two ways: the split RUN pays the payload forever, the joined one
#    does not. The layer that creates and deletes in one instruction weighs 0B.
payload_layer=$(docker image history --no-trunc --format '{{.Size}}|{{.CreatedBy}}' "$TAG" \
  | { grep 'payload.bin' || true; } | head -1 | cut -d'|' -f1)
if [ -z "$payload_layer" ]; then
  echo "UNEXPECTED: no layer creates the payload - is TODO 1 filled in?" >&2; exit 1
fi
if [ "$payload_layer" != "0B" ]; then
  echo "UNEXPECTED: the payload layer weighs $payload_layer, expected 0B (same-RUN cleanup)" >&2; exit 1
fi
clean_bytes=$(docker image inspect -f '{{.Size}}' "$TAG")
naive_bytes=$(docker image inspect -f '{{.Size}}' "$TAG_NAIVE")
delta_mb=$(( (naive_bytes - clean_bytes) / 1000000 ))
if [ "$delta_mb" -lt 6 ]; then
  echo "UNEXPECTED: the naive image is only ${delta_mb}MB heavier, expected at least 6MB" >&2; exit 1
fi
echo "OK 4 - one RUN or two: the payload layer weighs $payload_layer here, and the naive image carries ${delta_mb}MB more"

# 5. The ARG trap: build-time only for the process, forever for the metadata.
if ! docker image history --no-trunc --format '{{.CreatedBy}}' "$TAG" | grep -q "$BUILD_TOKEN"; then
  echo "UNEXPECTED: the build argument is not in the history - is TODO 3 filled in?" >&2; exit 1
fi
env_out=$(docker run --rm "$TAG" env)
if ! printf '%s\n' "$env_out" | grep -q '^GREETING=ciao'; then
  echo "UNEXPECTED: GREETING is not in the container environment" >&2; exit 1
fi
if printf '%s\n' "$env_out" | grep -q '^BUILD_TOKEN='; then
  echo "UNEXPECTED: BUILD_TOKEN survived into the container - ARG must not reach runtime" >&2; exit 1
fi
echo "OK 5 - ARG against ENV: the build value is readable in the history but absent at runtime, where GREETING is"

echo
echo "ALL CHECKS PASSED"
