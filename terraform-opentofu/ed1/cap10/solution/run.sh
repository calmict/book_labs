#!/usr/bin/env bash
set -euo pipefail

# Chapter 10 solution — the land registry, end to end:
#   0. the pre-existing world: the platform's network, created by hand;
#   1. the data block reads it DURING the plan — the netcard's content
#      arrives already resolved (chapter 9's reverse);
#   2. in the same plan, block B shows the deferred case: a data reading
#      a network born in this run -> freshcard (known after apply);
#   3. apply: the container lives in the platform's network (172.28.x);
#   4. reading is not owning: destroy removes our 5 resources, the
#      platform's network survives — and is then removed by hand.
#
# Needs a running Docker engine. Runs in a throwaway temp dir; guaranteed
# cleanup (destroy + network removal + rm) on exit.

DIR=$(cd "$(dirname "$0")" && pwd)
NET=cap10-platform-net

if command -v tofu >/dev/null 2>&1; then
  TF=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF=terraform
else
  echo "ERROR: neither tofu nor terraform found (see SETUP.md)" >&2
  exit 1
fi
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found" >&2; exit 1; }

WORK=$(mktemp -d)
cleanup() {
  (cd "$WORK" 2>/dev/null && "$TF" destroy -input=false -auto-approve >/dev/null 2>&1) || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

cp "$DIR/main.tf" "$WORK/"
cd "$WORK"

echo "== 0. The pre-existing world (the platform team, by hand) =="
docker network rm "$NET" >/dev/null 2>&1 || true
docker network create --subnet 172.28.0.0/16 "$NET" >/dev/null
echo "  $NET created — it exists, it has an owner, and it is not us"
echo

echo "== 1. Read during the plan: the resolved card =="
"$TF" init -input=false >/dev/null
"$TF" plan -input=false -no-color > plan.out 2>&1
grep -E 'data\.docker_network\.platform: Read complete' plan.out | sed 's/^/  /'
grep -E 'network id : [0-9a-f]{64}' plan.out >/dev/null
echo "  the netcard's content is ALREADY RESOLVED in the plan (real id, real driver)"
echo

echo "== 2. Same plan, the deferred case: the unknown returns =="
grep -A 3 'local_file.freshcard' plan.out | grep -E 'content += +\(known after apply\)' | head -1 | sed 's/^ */  freshcard: /'
echo "  (its data reads a network born in this run: the read slips to apply)"
echo

echo "== 3. Building on someone else's ground =="
"$TF" apply -input=false -auto-approve >/dev/null
ip=$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}: {{$v.IPAddress}}{{end}}' cap10-web)
echo "  cap10-web -> ${ip}"
case "$ip" in *"$NET"*172.28.*) : ;; *) echo "unexpected network placement"; exit 1 ;; esac
grep -E '^fresh network id : [0-9a-f]{64}$' freshcard.txt >/dev/null
echo "  freshcard resolved at apply: $(cat freshcard.txt)"
echo "  data. entries in the state:"
"$TF" state list | grep '^data\.' | sed 's/^/    /'
test "$("$TF" state list | grep -c '^data\.')" -eq 2
echo

echo "== 4. Reading is not owning =="
"$TF" destroy -input=false -auto-approve -no-color | grep -E '^Destroy complete' | sed 's/^/  /'
docker network ls --format '{{.Name}}' | grep -qx "$NET"
echo "  $NET survives: read, never owned — the registry does not burn with the house"
docker network rm "$NET" >/dev/null
echo "  removed by hand, as it was created"
echo

echo "=== a resource imposes, a data consults — and what you consult is never yours to destroy ==="
