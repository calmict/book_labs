#!/usr/bin/env bash
# cap17 solution - "the private switchboard": a user-defined bridge vs the default
# bridge. On a custom network Docker runs an embedded DNS, so a container reaches
# another by name; on the default bridge names do not resolve; and a container off
# the custom network cannot reach its members, not even by IP (networks are
# isolated). A uniquely named network and throwaway containers, all removed at the
# end; the default bridge is never touched, no restart, no privileges.
set -euo pipefail

OUT="${1:?usage: irete.sh OUTPUT_DIR}"
mkdir -p "$OUT"
NET="cap17-$$"
A="cap17a-$$"; B="cap17b-$$"; DA="cap17da-$$"; DB="cap17db-$$"
LOOP="cap17loop-$$"; ALL="cap17all-$$"
cleanup() {
  docker rm -f "$A" "$B" "$DA" "$DB" "$LOOP" "$ALL" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$NET" >/dev/null
docker run -d --name "$A" --network "$NET" busybox sleep 120 >/dev/null
docker run -d --name "$B" --network "$NET" busybox sleep 120 >/dev/null
docker run -d --name "$DA" busybox sleep 120 >/dev/null
docker run -d --name "$DB" busybox sleep 120 >/dev/null

# TODO 1 (17.2): on the custom network, A reaches B by NAME (embedded DNS).
custom_name=$(docker exec "$A" sh -c "ping -c1 -w2 $B >/dev/null 2>&1 && echo OK || echo FAIL")

# TODO 2 (17.1): on the default bridge, name resolution does not work.
default_name=$(docker exec "$DA" sh -c "ping -c1 -w2 $DB >/dev/null 2>&1 && echo OK || echo FAIL")

# TODO 3 (17.3): a container off the custom network cannot reach B, even by IP.
b_ip=$(docker exec "$B" sh -c 'ip addr show eth0 | grep -w inet | grep -oE "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" | head -1')
isolation=$(docker exec "$DA" sh -c "ping -c1 -w2 $b_ip >/dev/null 2>&1 && echo REACHED || echo BLOCKED")

# TODO 4 (17.4): compare loopback-only and all-interface publication.
docker run -d --name "$LOOP" -p 127.0.0.1::8080 busybox httpd -f -p 8080 >/dev/null
docker run -d --name "$ALL" -p 0.0.0.0::8080 busybox httpd -f -p 8080 >/dev/null
loop_port=$(docker port "$LOOP" 8080/tcp | awk -F: 'NR==1 {print $NF}')
all_port=$(docker port "$ALL" 8080/tcp | awk -F: 'NR==1 {print $NF}')
host_ip=$(hostname -I | awk '{print $1}')
loop_local=$(curl -sS --max-time 2 "http://127.0.0.1:$loop_port/" >/dev/null && echo REACHED || echo BLOCKED)
loop_host=$(curl -sS --max-time 2 "http://$host_ip:$loop_port/" >/dev/null 2>&1 && echo REACHED || echo BLOCKED)
all_host=$(curl -sS --max-time 2 "http://$host_ip:$all_port/" >/dev/null && echo REACHED || echo BLOCKED)

{
  echo "custom_name=$custom_name"
  echo "default_name=$default_name"
  echo "isolation=$isolation"
  echo "b_ip=$b_ip"
  echo "loop_local=$loop_local"
  echo "loop_host=$loop_host"
  echo "all_host=$all_host"
} > "$OUT/net.txt"
