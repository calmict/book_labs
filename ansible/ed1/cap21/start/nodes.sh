#!/usr/bin/env bash
# cap21 - the platform. An ISOLATED Docker engine (docker-in-docker) is our
# "cloud": the inventory plugin queries it and sees ONLY the lab fleet, never any
# other container on your machine. Inside it live three labelled containers - the
# fleet, whose labels are the cloud tags.
set -euo pipefail

DIND=cap21-dind
DIND_PORT=23751
IMAGE=python:3.12-slim

# the host engine (manages the dind container itself), regardless of any ambient
# DOCKER_HOST that points at the isolated engine
hostdocker() { env -u DOCKER_HOST docker "$@"; }
# the isolated engine (manages the fleet inside)
dind() { DOCKER_HOST="tcp://127.0.0.1:$DIND_PORT" docker "$@"; }

up() {
  hostdocker rm -f "$DIND" >/dev/null 2>&1 || true
  hostdocker run -d --name "$DIND" --privileged -e DOCKER_TLS_CERTDIR="" \
    -p "$DIND_PORT:2375" docker:27-dind --host=tcp://0.0.0.0:2375 >/dev/null

  # wait until the isolated engine answers
  for _ in $(seq 1 30); do
    if dind info >/dev/null 2>&1; then break; fi
    sleep 1
  done

  dind pull -q "$IMAGE" >/dev/null
  dind run -d --name cap21-web1 --label role=web --label env=prod    "$IMAGE" sleep infinity >/dev/null
  dind run -d --name cap21-web2 --label role=web --label env=staging "$IMAGE" sleep infinity >/dev/null
  dind run -d --name cap21-db1  --label role=db  --label env=prod    "$IMAGE" sleep infinity >/dev/null

  echo "isolated engine up: $DIND (only the lab fleet lives here)"
  echo "fleet: cap21-web1 (web/prod), cap21-web2 (web/staging), cap21-db1 (db/prod)"
  echo "point ansible (and the docker connection) at it:"
  echo "    export DOCKER_HOST=tcp://127.0.0.1:$DIND_PORT"
}

down() {
  hostdocker rm -f "$DIND" >/dev/null 2>&1 || true
  echo "$DIND down (the whole fleet went with it)"
}

case "${1:-up}" in
  up) up ;;
  down) down ;;
  *) echo "usage: $0 [up|down]" >&2; exit 2 ;;
esac
