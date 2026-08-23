#!/usr/bin/env bash
# cap20 - solution test. Brings up the three-service Compose application and
# checks: the three services are running and the one behind a profile is not; web
# reaches db by service name (the declared network, with its embedded DNS); the
# file declares web depends_on db; the network and the named volume exist and are
# used; the profile service starts only when it is asked for; and the override file
# merges onto the base one, changing web only when both files are passed. Unique
# project name, torn down at the end, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
PROJ="cap20-$$"
COMPOSE="$HERE/compose.yaml"
OVERRIDE="$HERE/compose.override.yaml"
dc() { docker compose -p "$PROJ" -f "$COMPOSE" "$@"; }
dco() { docker compose -p "$PROJ" -f "$COMPOSE" -f "$OVERRIDE" "$@"; }
cleanup() { docker compose -p "$PROJ" -f "$COMPOSE" --profile tools down -v >/dev/null 2>&1 || true; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: docker compose plugin not found (see SETUP.md)" >&2; exit 1; }

dc up -d >/dev/null 2>&1

# 1. both services are running
running=$(docker ps -q --filter "label=com.docker.compose.project=$PROJ" | grep -c . || true)
if [ "$running" != "3" ]; then
  echo "UNEXPECTED: expected 3 running services, got $running" >&2; dc ps >&2; exit 1
fi
echo "OK 1 - the three services are up (db, web, cache)"

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

# 4. the declared network and named volume exist, and are the ones in use
net=$(docker network ls --filter "label=com.docker.compose.project=$PROJ" --format '{{.Name}}' | head -1)
vol=$(docker volume ls --filter "label=com.docker.compose.project=$PROJ" --format '{{.Name}}' | head -1)
if [ -z "$net" ] || [ -z "$vol" ]; then
  echo "UNEXPECTED: network='$net' volume='$vol' - the project declares both" >&2; exit 1
fi
# shellcheck disable=SC2016  # the Go template must reach docker unexpanded
on_net=$(docker ps -q --filter "label=com.docker.compose.project=$PROJ" \
  | xargs -r docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' \
  | grep -c "$net" || true)
if [ "$on_net" != "3" ]; then
  echo "UNEXPECTED: $on_net services on $net, expected 3" >&2; exit 1
fi
mounted=$(dc exec -T db sh -c 'mount | grep -c /var/lib/db' || true)
if [ "$mounted" -lt 1 ]; then
  echo "UNEXPECTED: db does not have the named volume mounted at /var/lib/db" >&2; exit 1
fi
echo "OK 4 - one network ($net) carrying all three, and a named volume ($vol) mounted by db"

# 5. profiles: declared but not started, unless asked for
if docker ps --filter "label=com.docker.compose.project=$PROJ" --format '{{.Names}}' | grep -q 'tools'; then
  echo "UNEXPECTED: the tools service started without its profile" >&2; exit 1
fi
dc --profile tools up -d tools >/dev/null 2>&1
if ! docker ps --filter "label=com.docker.compose.project=$PROJ" --format '{{.Names}}' | grep -q 'tools'; then
  echo "UNEXPECTED: the tools service did not start with --profile tools" >&2; exit 1
fi
echo "OK 5 - profiles: tools stays out of the default up, and starts only when asked for"

# 6. the override file merges onto the base one: web changes only with both files
# shellcheck disable=SC2016  # MODE must be read inside the container, not here
base_mode=$(dc exec -T web sh -c 'echo "${MODE:-unset}"')
dco up -d web >/dev/null 2>&1
# shellcheck disable=SC2016  # same: the expansion belongs to the container
merged_mode=$(dco exec -T web sh -c 'echo "${MODE:-unset}"')
if [ "$base_mode" != "unset" ] || [ "$merged_mode" != "development" ]; then
  echo "UNEXPECTED: MODE is '$base_mode' with the base file and '$merged_mode' with the override," >&2
  echo "            expected 'unset' and 'development'" >&2; exit 1
fi
echo "OK 6 - override: MODE is $base_mode with compose.yaml alone, $merged_mode once the override is merged"

echo
echo "ALL CHECKS PASSED"
