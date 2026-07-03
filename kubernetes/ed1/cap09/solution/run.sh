#!/usr/bin/env bash
set -euo pipefail

# Chapter 9 solution — the four gates of the apiserver, bare-handed with curl.
# Needs a reachable cluster (chapter 7's) and a free port 8001 for the proxy.

NS=quota-lab
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/lab-cap09.XXXXXX")
PROXY_PID=""
WATCH_PID=""

cleanup() {
  if [ -n "$PROXY_PID" ]; then kill "$PROXY_PID" 2>/dev/null || true; fi
  if [ -n "$WATCH_PID" ]; then kill "$WATCH_PID" 2>/dev/null || true; fi
  kubectl delete namespace "$NS" watch-lab --ignore-not-found >/dev/null 2>&1 || true
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}
kubectl delete namespace "$NS" watch-lab --ignore-not-found >/dev/null

# extract a credential from the kubeconfig: inline data if present,
# otherwise the file path (minikube style)
extract() {
  local data
  data=$(kubectl config view --raw --minify -o jsonpath="{$1-data}")
  if [ -n "$data" ]; then
    base64 -d <<< "$data" > "$2"
  else
    cp "$(kubectl config view --raw --minify -o jsonpath="{$1}")" "$2"
  fi
}

echo "== 1. The REST API without kubectl =="
kubectl proxy >/dev/null 2>&1 &
PROXY_PID=$!
sleep 2
curl -s http://127.0.0.1:8001/api
echo
APIGROUPS=$(curl -s http://127.0.0.1:8001/apis)
head -12 <<< "$APIGROUPS"
echo "..."

echo
echo "== 2. First gate: knocking with no papers =="
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
echo "server: $SERVER"
ANON=$(curl -sk "$SERVER/api/v1/namespaces" || true)
grep -E '"(code|reason|message)"' <<< "$ANON" || echo "$ANON"

echo
echo "== 3. In with the papers from the kubeconfig =="
extract '.users[0].user.client-certificate' "$WORKDIR/client.crt"
extract '.users[0].user.client-key' "$WORKDIR/client.key"
extract '.clusters[0].cluster.certificate-authority' "$WORKDIR/ca.crt"
WELCOME=$(curl -s --cert "$WORKDIR/client.crt" --key "$WORKDIR/client.key" \
  --cacert "$WORKDIR/ca.crt" "$SERVER/api/v1/namespaces")
head -6 <<< "$WELCOME"
echo "... (a 200 with the namespace list: kubectl never does anything else)"

echo
echo "== 4. Second gate: authenticated is not authorized =="
echo -n "can I create pods (as admin)? "
kubectl auth can-i create pods
echo "--- the same request, impersonating a humble identity ---"
set +e
kubectl get pods --as=system:serviceaccount:default:default 2>&1 | tail -1
set -e

echo
echo "== 5. Third gate: admission (ResourceQuota) =="
kubectl create namespace "$NS"
kubectl create quota one-pod-only --hard=pods=1 -n "$NS"
sleep 3
kubectl run sleeper1 -n "$NS" --image=alpine:3 -- sleep infinity
set +e
REJECT=$(kubectl run sleeper2 -n "$NS" --image=alpine:3 -- sleep infinity 2>&1)
RC=$?
set -e
echo "$REJECT"
if [ "$RC" -ne 0 ]; then
  echo "(rejected on the merits by the ResourceQuota admission plugin:"
  echo " authenticated yes, authorized yes, welcome no)"
else
  echo "WARNING: the second pod was not rejected — quota not enforced?" >&2
fi

echo
echo "== 6. The watch stream =="
curl -sN "http://127.0.0.1:8001/api/v1/namespaces?watch=1" > "$WORKDIR/watch.log" &
WATCH_PID=$!
sleep 1
kubectl create namespace watch-lab >/dev/null
kubectl delete namespace watch-lab >/dev/null
sleep 2
kill "$WATCH_PID" 2>/dev/null || true
WATCH_PID=""
echo "--- events seen on the stream while watch-lab lived and died ---"
grep -o '"type":"[A-Z]*"' "$WORKDIR/watch.log" | sort | uniq -c
echo
echo "One connection, every change pushed as it happens: this is how the"
echo "controllers of chapter 7 notice a difference the instant it appears."
