#!/usr/bin/env bash
set -euo pipefail

# Chapter 27 solution — the escort: Istio service mesh. Each pod gets an
# Envoy sidecar (injected automatically), sidecars encrypt and mutually
# authenticate every call (mTLS), and traffic is split between two versions
# from above (canary), all without changing the app. Runs on a dedicated
# throwaway kind cluster, because Istio installs cluster-wide CRDs and a
# mutating webhook.

DIR=$(cd "$(dirname "$0")" && pwd)
CLUSTER=book-labs-mesh
CTX=kind-${CLUSTER}

command -v kind >/dev/null || { echo "ERROR: kind not found" >&2; exit 1; }
command -v istioctl >/dev/null || { echo "ERROR: istioctl not found — install it (see prerequisites)" >&2; exit 1; }

PREV_CTX=$(kubectl config current-context 2>/dev/null || true)
cleanup() {
  kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
  if [ -n "$PREV_CTX" ]; then
    kubectl config use-context "$PREV_CTX" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

kc() { kubectl --context "$CTX" "$@"; }

echo "== 0. A dedicated cluster + Istio =="
kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
kind create cluster --name "$CLUSTER" >/dev/null 2>&1
echo "  cluster $CLUSTER created"
istioctl install --context "$CTX" --set profile=minimal -y >/dev/null 2>&1
echo "  Istio installed (minimal profile: just the control plane, istiod)"
echo

echo "== 1. The escort attaches itself (sidecar injection) =="
kc apply -f "$DIR/../start/mesh-app.yaml" >/dev/null
kc -n mesh wait --for=condition=Ready pod --all --timeout=180s >/dev/null
kc -n mesh get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.status.containerStatuses[*].name' \
  | sed 's/^/  /'
echo "  (two containers per pod: your app + istio-proxy — added automatically)"
echo

echo "== 2. Identity and encryption for free (mTLS STRICT) =="
kc apply -f "$DIR/../start/mtls.yaml" >/dev/null
kc -n outside run oclient --image=curlimages/curl:8.11.1 --restart=Never \
  --command -- sleep infinity >/dev/null
kc -n outside wait --for=condition=Ready pod/oclient --timeout=90s >/dev/null
sleep 3
code=$(kc -n outside exec oclient -- \
  curl -s -m 5 -o /dev/null -w '%{http_code}' http://web.mesh/ 2>/dev/null || true)
if [ "$code" = "000" ] || [ -z "$code" ]; then
  echo "  outside (no sidecar) -> web.mesh: REFUSED (plaintext not allowed)"
else
  echo "  outside -> web.mesh: got HTTP $code — STRICT mTLS is NOT enforcing" >&2
  exit 1
fi
inside=$(kc -n mesh exec client -c client -- curl -s -m 5 http://web/ 2>/dev/null || true)
echo "  inside (with sidecar) -> web: got '$inside' over automatic mutual TLS"
echo

echo "== 3. Steering traffic from above (canary 80/20) =="
kc apply -f "$DIR/canary.yaml" >/dev/null
sleep 3
echo "  30 requests from the in-mesh client:"
# single quotes are intentional: the loop must expand inside the client pod
# shellcheck disable=SC2016
kc -n mesh exec client -c client -- \
  sh -c 'for _ in $(seq 1 30); do curl -s http://web/; done' \
  | sort | uniq -c | sed 's/^/   /'
echo "  (~80% v1, ~20% v2 — a canary decided by the VirtualService, app untouched)"
echo
echo "=== the app spoke plainly; the escort handled security and routing ==="
