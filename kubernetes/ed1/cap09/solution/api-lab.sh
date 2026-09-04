#!/usr/bin/env bash
# Chapter 9 completed commands. The verifier performs this sequence with
# temporary credentials, automatic port selection, assertions, and cleanup.
set -euo pipefail

PORT=${CAP09_PORT:-8001}
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

kubectl proxy --port="$PORT" &
PROXY_PID=$!
trap 'kill "$PROXY_PID" 2>/dev/null || true' EXIT
sleep 2
curl -s "http://127.0.0.1:$PORT/api"
curl -s "http://127.0.0.1:$PORT/apis"

curl -sk -H 'Authorization: Bearer deliberately-invalid' "$SERVER/api/v1/namespaces"
kubectl get pods --as=system:serviceaccount:default:default || true
kubectl create namespace quota-lab
kubectl create quota one-pod-only --hard=pods=1 -n quota-lab
kubectl run sleeper1 -n quota-lab --image=alpine:3 -- sleep infinity
kubectl run sleeper2 -n quota-lab --image=alpine:3 -- sleep infinity || true

curl -sN "http://127.0.0.1:$PORT/api/v1/namespaces?watch=1" &
WATCH_PID=$!
kubectl create namespace watch-lab
kubectl delete namespace watch-lab
kill "$WATCH_PID" 2>/dev/null || true
kubectl delete namespace quota-lab --ignore-not-found
