#!/usr/bin/env bash
# cap17 - solution test. Proves the difference between a user-defined bridge and
# the default one: on the custom network a container reaches another by name
# (embedded DNS); on the default bridge the name does not resolve; and a container
# off the custom network cannot reach its members even by IP (isolation).
# Throwaway containers and a uniquely named network, no restart, no privileges.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

command -v docker >/dev/null || { echo "ERROR: docker not found (see SETUP.md)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: cannot reach the Docker daemon (see SETUP.md)" >&2; exit 1; }

val() { grep "^$2=" "$1" | cut -d= -f2-; }

"$HERE/irete.sh" "$WORK"
custom_name=$(val "$WORK/net.txt" custom_name)
default_name=$(val "$WORK/net.txt" default_name)
isolation=$(val "$WORK/net.txt" isolation)
b_ip=$(val "$WORK/net.txt" b_ip)

# 1. on the custom network, name resolution works (embedded DNS)
if [ "$custom_name" != "OK" ]; then
  echo "UNEXPECTED: on the custom network A did not reach B by name (custom_name=$custom_name)" >&2; exit 1
fi
echo "OK 1 - custom bridge DNS: A reaches B by name (OK)"

# 2. on the default bridge, name resolution does not work
if [ "$default_name" != "FAIL" ]; then
  echo "UNEXPECTED: the default bridge resolved a container name (default_name=$default_name)" >&2; exit 1
fi
echo "OK 2 - default bridge: name does not resolve (FAIL, as expected)"

# 3. a container off the custom network cannot reach B, even by IP (isolation)
if [ "$isolation" != "BLOCKED" ]; then
  echo "UNEXPECTED: a container off the network reached B at $b_ip (isolation=$isolation)" >&2; exit 1
fi
echo "OK 3 - isolation: a container off the network cannot reach B at $b_ip (BLOCKED)"

echo
echo "ALL CHECKS PASSED"
