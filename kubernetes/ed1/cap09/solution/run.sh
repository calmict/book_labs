#!/usr/bin/env bash
# Chapter 9 verification - uses curl against the API, checks authentication,
# authorization and admission outcomes, and captures a namespace watch stream.
# Requires kubectl, curl, base64, and a reachable cluster. Namespaced, throwaway.
set -euo pipefail

NS=quota-lab
WATCH_NS=watch-lab
WORK=$(mktemp -d)
PROXY_PID=""
WATCH_PID=""

cleanup() {
  if [ -n "$WATCH_PID" ]; then kill "$WATCH_PID" 2>/dev/null || true; fi
  if [ -n "$PROXY_PID" ]; then kill "$PROXY_PID" 2>/dev/null || true; fi
  kubectl delete namespace "$NS" "$WATCH_NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster - see chapter 7" >&2
  exit 1
}
kubectl delete namespace "$NS" "$WATCH_NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
kubectl wait --for=delete namespace/"$NS" --timeout=120s >/dev/null 2>&1 || true
kubectl wait --for=delete namespace/"$WATCH_NS" --timeout=120s >/dev/null 2>&1 || true

PORT=${CAP09_PORT:-8001}
while (echo > "/dev/tcp/127.0.0.1/$PORT") >/dev/null 2>&1; do
  PORT=$((PORT + 1))
done
if [ "$PORT" != "${CAP09_PORT:-8001}" ]; then
  echo "PRECHECK requested proxy port is occupied: using $PORT"
else
  echo "PRECHECK proxy port $PORT is free"
fi

kubectl proxy --port="$PORT" >"$WORK/proxy.log" 2>&1 &
PROXY_PID=$!
for _ in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:$PORT/api" >"$WORK/api.json"; then break; fi
  sleep 1
done
curl -sf "http://127.0.0.1:$PORT/apis" >"$WORK/apis.json"
grep -q '"v1"' "$WORK/api.json"
grep -q 'apps' "$WORK/apis.json"
echo "OK 1 - plain curl discovers the core API and named API groups"

SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
AUTHN_CODE=$(curl -sk -H 'Authorization: Bearer deliberately-invalid' \
  -o "$WORK/authentication.json" -w '%{http_code}' "$SERVER/api/v1/namespaces")
test "$AUTHN_CODE" = 401
grep -qi 'Unauthorized' "$WORK/authentication.json"
echo "OK 2 - the authentication gate rejects an invalid credential with HTTP 401"

extract() {
  local field=$1
  local target=$2
  local data path
  data=$(kubectl config view --raw --minify -o jsonpath="{$field-data}")
  if [ -n "$data" ]; then
    base64 -d <<< "$data" > "$target"
  else
    path=$(kubectl config view --raw --minify -o jsonpath="{$field}")
    cp "$path" "$target"
  fi
}
extract '.users[0].user.client-certificate' "$WORK/client.crt"
extract '.users[0].user.client-key' "$WORK/client.key"
extract '.clusters[0].cluster.certificate-authority' "$WORK/ca.crt"
AUTH_CODE=$(curl -s --cert "$WORK/client.crt" --key "$WORK/client.key" \
  --cacert "$WORK/ca.crt" -o "$WORK/authenticated.json" -w '%{http_code}' \
  "$SERVER/api/v1/namespaces")
test "$AUTH_CODE" = 200
grep -q 'NamespaceList' "$WORK/authenticated.json"
echo "OK 3 - the kubeconfig certificates admit the same curl request"

set +e
RBAC=$(kubectl get pods --as=system:serviceaccount:default:default 2>&1)
RBAC_RC=$?
set -e
test "$RBAC_RC" -ne 0
grep -qi 'forbidden' <<< "$RBAC"
echo "OK 4 - the authorization gate rejects an authenticated unprivileged identity"

kubectl create namespace "$NS" >/dev/null
kubectl create quota one-pod-only --hard=pods=1 -n "$NS" >/dev/null
kubectl run sleeper1 -n "$NS" --image=alpine:3 -- sleep infinity >/dev/null
set +e
QUOTA=$(kubectl run sleeper2 -n "$NS" --image=alpine:3 -- sleep infinity 2>&1)
QUOTA_RC=$?
set -e
test "$QUOTA_RC" -ne 0
grep -qi 'exceeded quota' <<< "$QUOTA"
echo "OK 5 - the admission gate rejects a second Pod over quota"

curl -sN "http://127.0.0.1:$PORT/api/v1/namespaces?watch=1" >"$WORK/watch.log" &
WATCH_PID=$!
sleep 1
kubectl create namespace "$WATCH_NS" >/dev/null
kubectl delete namespace "$WATCH_NS" --wait=true >/dev/null
for _ in $(seq 1 30); do
  if grep -q '"type":"DELETED".*"name":"watch-lab"' "$WORK/watch.log"; then break; fi
  sleep 1
done
grep -q '"type":"ADDED".*"name":"watch-lab"' "$WORK/watch.log"
grep -q '"type":"DELETED".*"name":"watch-lab"' "$WORK/watch.log"
echo "OK 6 - one watch stream receives watch-lab ADDED and DELETED events"

cleanup
PROXY_PID=""
WATCH_PID=""
kubectl wait --for=delete namespace/"$NS" --timeout=120s >/dev/null
if kubectl get namespace "$WATCH_NS" >/dev/null 2>&1; then
  echo "UNEXPECTED: watch-lab survived cleanup" >&2
  exit 1
fi
echo "OK 7 - namespaces, proxy, watch, and temporary certificates were removed"

echo
echo "ALL CHECKS PASSED"
