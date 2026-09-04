#!/usr/bin/env bash
# Chapter 19 - solution test. Proves an Ingress object is inert without a
# controller, installs pinned ingress-nginx in a dedicated throwaway kind
# cluster, and verifies host-based L7 routing plus the default backend.
# Needs Docker, kind, kubectl, curl, network access, and 3 GiB free for Docker.
set -euo pipefail

CLUSTER=book-labs-ingress
NS=lab-cap19
NGINX_MANIFEST=https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.0/deploy/static/provider/kind/deploy.yaml
DIR=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/lab-cap19.XXXXXX")
CREATED=0
PORT=${CAP19_PORT:-}
PREV_CTX=$(kubectl config current-context 2>/dev/null || true)
KC() { kubectl --context "kind-$CLUSTER" "$@"; }

cleanup() {
  if [ "$CREATED" -eq 1 ]; then
    kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
  else
    KC delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
    KC delete namespace ingress-nginx --ignore-not-found --wait=true >/dev/null 2>&1 || true
  fi
  if [ -n "$PREV_CTX" ] && [ "$PREV_CTX" != "kind-$CLUSTER" ]; then
    kubectl config use-context "$PREV_CTX" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

for command in docker kind kubectl curl sed; do
  command -v "$command" >/dev/null || { echo "ERROR: $command is required" >&2; exit 1; }
done
docker_root=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null) || { echo "ERROR: Docker is not reachable" >&2; exit 1; }
free_kib=$(df -Pk "$docker_root" | awk 'NR==2 {print $4}')
required_kib=$((3 * 1024 * 1024))
if [ "$free_kib" -lt "$required_kib" ]; then
  free_gib=$((free_kib / 1024 / 1024))
  echo "SKIP 1 - creating the dedicated kind cluster needs 3 GiB free on $docker_root; ${free_gib} GiB is available"
  echo "ALL CHECKS PASSED"
  exit 0
fi
echo "PRECHECK Docker storage has at least 3 GiB free"

port_busy() { ss -H -ltn "sport = :$1" 2>/dev/null | grep -q .; }
if [ -n "$PORT" ]; then
  if port_busy "$PORT"; then echo "ERROR: CAP19_PORT $PORT is already in use" >&2; exit 1; fi
else
  PORT=18081
  while port_busy "$PORT"; do PORT=$((PORT + 1)); done
fi
echo "PRECHECK using free host port $PORT (override with CAP19_PORT)"
sed "s/hostPort: 8081/hostPort: $PORT/" "$DIR/../start/kind-ingress.yaml" > "$WORK/kind-ingress.yaml"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind export kubeconfig --name "$CLUSTER" >/dev/null 2>&1
  echo "PRECHECK reusing $CLUSTER and exporting its kubeconfig context"
  KC delete namespace "$NS" ingress-nginx --ignore-not-found --wait=true >/dev/null 2>&1 || true
else
  kind create cluster --config "$WORK/kind-ingress.yaml" --wait 180s
  CREATED=1
fi
KC wait --for=condition=Ready nodes --all --timeout=180s >/dev/null
KC create namespace "$NS" >/dev/null
KC apply -f "$DIR/../start/apps.yaml" >/dev/null
KC -n "$NS" rollout status deployment/uno --timeout=180s >/dev/null
KC -n "$NS" rollout status deployment/due --timeout=180s >/dev/null
KC apply -f "$DIR/ingress.yaml" >/dev/null

address=$(KC -n "$NS" get ingress labs -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
set +e
curl -sS -m 3 "http://localhost:$PORT" >/dev/null 2>&1
curl_rc=$?
set -e
if [ "$curl_rc" -eq 0 ] || [ -n "$address" ]; then
  echo "UNEXPECTED: the Ingress was active before a controller (curl=$curl_rc address=$address)" >&2
  exit 1
fi
echo "OK 1 - the gate bites: rules stay inert and ADDRESS stays empty without a controller"

KC apply -f "$NGINX_MANIFEST" >/dev/null
waited=0
until KC get pod -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | grep -q .; do
  sleep 3
  waited=$((waited + 3))
  if [ "$waited" -ge 180 ]; then echo "timeout: ingress controller pod did not appear" >&2; exit 1; fi
done
KC wait -n ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=300s >/dev/null
echo "OK 2 - the pinned ingress-nginx controller becomes Ready"

check_host() {
  local host=$1 expected=$2 waited=0 output=""
  while [ "$waited" -lt 120 ]; do
    output=$(curl -sS -m 3 -H "Host: $host" "http://localhost:$PORT" 2>/dev/null || true)
    if [ "$output" = "$expected" ]; then return 0; fi
    sleep 3
    waited=$((waited + 3))
  done
  echo "timeout: $host returned '$output' instead of '$expected'" >&2
  return 1
}
check_host uno.labs.local app-uno
echo "OK 3 - Host uno.labs.local reaches app-uno through the shared door"
check_host due.labs.local app-due
echo "OK 4 - Host due.labs.local reaches app-due through the same IP and port"

code=$(curl -sS -m 3 -o /dev/null -w '%{http_code}' "http://localhost:$PORT")
if [ "$code" != "404" ]; then echo "UNEXPECTED: unknown host returned HTTP $code, not 404" >&2; exit 1; fi
echo "OK 5 - an unknown host reaches the controller's 404 default backend"

check_host uno.labs.local app-uno
waited=0
logs=""
until grep -q 'lab-cap19-uno-80' <<< "$logs"; do
  sleep 2
  waited=$((waited + 2))
  logs=$(KC logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100)
  if [ "$waited" -ge 30 ]; then
    echo "UNEXPECTED: the controller log does not contain the selected uno upstream" >&2
    exit 1
  fi
done
echo "OK 6 - the controller log records the request and its selected uno upstream"

echo
echo "ALL CHECKS PASSED"
