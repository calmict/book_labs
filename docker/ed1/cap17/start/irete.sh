#!/usr/bin/env bash
# cap17 start - custom bridge vs default bridge, to complete. The network and
# containers are set up; the three key measurements are missing. Three gaps
# (TODO 1..3): name resolution (custom and default) and isolation are empty and
# the test fails. Uniquely named network and throwaway containers.
set -euo pipefail

OUT="${1:?usage: irete.sh OUTPUT_DIR}"
mkdir -p "$OUT"
NET="cap17-$$"
A="cap17a-$$"; B="cap17b-$$"; DA="cap17da-$$"; DB="cap17db-$$"
cleanup() {
  docker rm -f "$A" "$B" "$DA" "$DB" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$NET" >/dev/null
docker run -d --name "$A" --network "$NET" busybox sleep 120 >/dev/null
docker run -d --name "$B" --network "$NET" busybox sleep 120 >/dev/null
docker run -d --name "$DA" busybox sleep 120 >/dev/null
docker run -d --name "$DB" busybox sleep 120 >/dev/null

# TODO 1 (17.2): on the custom network, have A reach B by NAME (embedded DNS):
#     custom_name=$(docker exec "$A" sh -c "ping -c1 -w2 $B >/dev/null 2>&1 && echo OK || echo FAIL")
custom_name=""

# TODO 2 (17.1): on the default bridge, try to reach a container by name (no DNS):
#     default_name=$(docker exec "$DA" sh -c "ping -c1 -w2 $DB >/dev/null 2>&1 && echo OK || echo FAIL")
default_name=""

# TODO 3 (17.3): from a container off the custom network, try to reach B by IP:
#     b_ip=$(docker exec "$B" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')
#     isolation=$(docker exec "$DA" sh -c "ping -c1 -w2 $b_ip >/dev/null 2>&1 && echo REACHED || echo BLOCKED")
b_ip=""
isolation=""

{
  echo "custom_name=$custom_name"
  echo "default_name=$default_name"
  echo "isolation=$isolation"
  echo "b_ip=$b_ip"
} > "$OUT/net.txt"
