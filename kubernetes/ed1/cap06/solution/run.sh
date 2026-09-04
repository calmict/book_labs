#!/usr/bin/env bash
# Chapter 6 verification - creates a rootless user/network namespace, mounts a
# private /run, and proves veth, bridge, ping, ARP, and FDB behaviour. The
# contrast leaves red's veth down and requires the ping to fail. Throwaway.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
cleanup() {
  docker rm -f lab-cap06 >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

run_inner() {
  # shellcheck disable=SC2016  # positional parameters expand in the inner shell
  unshare -Urnm sh -c 'mount -t tmpfs tmpfs /run; exec "$1" "$2"' sh \
    "$HERE/network-lab.sh" "$1"
}

run_inner "$WORK/result"

grep -q '0% packet loss' "$WORK/result/ping.txt"
echo "OK 1 - blue reaches red through the virtual switch"

red_mac=$(awk '/lladdr/ {print $5}' "$WORK/result/neigh.txt")
test -n "$red_mac"
grep -q "$red_mac" "$WORK/result/fdb.txt"
echo "OK 2 - blue's ARP table records red's MAC and the bridge FDB learns it"

grep -q 'veth-blue-br' "$WORK/result/ports.txt"
grep -q 'veth-red-br' "$WORK/result/ports.txt"
docker run -d --name lab-cap06 alpine:3 sleep infinity >/dev/null
ip -o link show master docker0 > "$WORK/docker0-ports.txt"
grep -q 'veth' "$WORK/docker0-ports.txt"
docker rm -f lab-cap06 >/dev/null
echo "OK 3 - br-lab and docker0 expose the same bridge-plus-veth layout"

if CAP06_RED_DOWN=1 run_inner "$WORK/contrast" >/dev/null 2>&1; then
  echo "UNEXPECTED: ping succeeded while red's veth was down" >&2
  exit 1
fi
echo "OK 4 - the gate bites: with red's veth down, the same ping fails"

if ip netns list | grep -Eq '(^|[[:space:]])(blue|red)([[:space:]]|$)' || ip link show br-lab >/dev/null 2>&1; then
  echo "UNEXPECTED: a lab network escaped into the host namespace" >&2
  exit 1
fi
echo "OK 5 - the toy network vanished without leaving host interfaces or namespaces"

echo
echo "ALL CHECKS PASSED"
