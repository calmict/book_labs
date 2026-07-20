#!/usr/bin/env bash
# cap11 - solution test. Builds the Multi-Stage image and checks: the final image
# carries the artifact (OK 1) and NOT the build-stage files - it is light and
# clean (OK 2); and, ordering the dependencies before the source, changing only
# the source keeps the dependency-install step CACHED while the source is rebuilt
# (OK 3). Throwaway images, no restart, no privileges.
set -euo pipefail
export DOCKER_BUILDKIT=1

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
TAG="cap11-$$"
cleanup() { docker rmi -f "$TAG" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

# mutable copy of the build context, so the cache test can edit the source
cp "$HERE/Dockerfile" "$HERE/deps.txt" "$HERE/app.txt" "$WORK/"

# warm build (populates the layer cache)
docker build -q -t "$TAG" "$WORK" >/dev/null

# 1. the final image carries the artifact built from the source
out=$(docker run --rm "$TAG")
if [ "$out" != "app-v1" ]; then
  echo "UNEXPECTED: final image printed '$out', expected 'app-v1'" >&2; exit 1
fi
echo "OK 1 - the final image carries the artifact (prints '$out')"

# 2. Multi-Stage isolation: the artifact is there, the build-stage files are not
if ! docker run --rm "$TAG" sh -c '[ -f /app ] && [ ! -e /out/deps-installed.txt ] && [ ! -e /src/deps.txt ]'; then
  echo "UNEXPECTED: the final image is not clean (build-stage files leaked, or /app missing)" >&2; exit 1
fi
echo "OK 2 - Multi-Stage isolation: only /app shipped, no build-stage files"

# 3. strategic cache: change only the source, rebuild, and inspect what is CACHED
step_cached() {  # $1 = build output ; $2 = token in the step's command line
  local id
  id=$(printf '%s\n' "$1" | grep -F "$2" | grep -oE '^#[0-9]+' | head -1)
  [ -n "$id" ] || { echo "missing"; return; }
  if printf '%s\n' "$1" | grep -qE "^${id} CACHED"; then echo "yes"; else echo "no"; fi
}

printf 'app-%s\n' "$$" > "$WORK/app.txt"   # unique source content, never pre-cached
build_out=$(docker build --progress=plain -t "$TAG" "$WORK" 2>&1)
deps_cached=$(step_cached "$build_out" 'deps-installed')
src_cached=$(step_cached "$build_out" 'cat app.txt')
if [ "$deps_cached" != "yes" ] || [ "$src_cached" = "yes" ]; then
  echo "UNEXPECTED: after a source-only change, deps cached=$deps_cached (want yes), source cached=$src_cached (want no)" >&2
  exit 1
fi
echo "OK 3 - strategic cache: dependency step CACHED, source rebuilt (order pays off)"

echo
echo "ALL CHECKS PASSED"
