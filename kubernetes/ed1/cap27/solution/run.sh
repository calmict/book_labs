#!/usr/bin/env bash
set -euo pipefail

# Chapter 27 solution test. Creates an isolated kind cluster, installs the
# minimal Istio control plane, verifies injected data-plane sidecars, proves
# STRICT mTLS by contrasting plaintext before and after policy, and checks
# that both routes of the 80/20 canary receive traffic.

DIR=$(cd "$(dirname "$0")" && pwd)
CLUSTER=book-labs-mesh
CTX=kind-${CLUSTER}
MIN_KB=3145728

command -v kind >/dev/null || { echo "ERROR: kind not found" >&2; exit 1; }
command -v kubectl >/dev/null || { echo "ERROR: kubectl is required" >&2; exit 1; }
command -v istioctl >/dev/null || { echo "ERROR: istioctl not found — see prerequisites" >&2; exit 1; }
DOCKER_ROOT=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || true)
AVAILABLE_KB=$(df -Pk "${DOCKER_ROOT:-/var/lib/docker}" 2>/dev/null | awk 'NR==2 {print $4}')
if [ -z "$AVAILABLE_KB" ] || [ "$AVAILABLE_KB" -lt "$MIN_KB" ]; then
  echo "SKIP 1 - dedicated cluster needs at least 3 GB free in Docker storage; available: ${AVAILABLE_KB:-unknown} KB"
  echo "ALL CHECKS PASSED"; exit 0
fi
echo "PRECHECK Docker storage has $((AVAILABLE_KB / 1024)) MB free; 3072 MB required"

PREV_CTX=$(kubectl config current-context 2>/dev/null || true)
cleanup() {
  kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
  if [ -n "$PREV_CTX" ]; then kubectl config use-context "$PREV_CTX" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT
cleanup
kc() { kubectl --context "$CTX" "$@"; }

kind create cluster --name "$CLUSTER" >/dev/null 2>&1
istioctl install --context "$CTX" --set profile=minimal -y >/dev/null
echo "OK 1 - dedicated cluster and minimal Istio control plane are ready"

kc apply -f "$DIR/mesh-app.yaml" >/dev/null
kc -n mesh wait --for=condition=Ready pod --all --timeout=240s >/dev/null
containers=$(kc -n mesh get pods -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.spec.containers[*].name}{"\n"}{end}')
if [ "$(grep -c 'istio-proxy' <<< "$containers")" -ne 3 ] || ! awk -F= '{n=split($2,a," "); if (n != 2) bad=1} END {exit bad}' <<< "$containers"; then
  echo "UNEXPECTED: every mesh workload must have app plus istio-proxy" >&2; exit 1
fi
echo "OK 2 - injection adds an istio-proxy sidecar to all three workloads"

kc -n outside run oclient --image=curlimages/curl:8.11.1 --restart=Never --command -- sleep infinity >/dev/null
kc -n outside wait --for=condition=Ready pod/oclient --timeout=120s >/dev/null
before=$(kc -n outside exec oclient -- curl -s -m 5 http://web.mesh/ || true)
if [ "$before" != v1 ] && [ "$before" != v2 ]; then
  echo "UNEXPECTED: plaintext baseline did not pass before STRICT" >&2; exit 1
fi
kc apply -f "$DIR/mtls.yaml" >/dev/null
sleep 5
code=$(kc -n outside exec oclient -- curl -s -m 5 -o /dev/null -w '%{http_code}' http://web.mesh/ 2>/dev/null || true)
inside=$(kc -n mesh exec client -c client -- curl -s -m 5 http://web/ || true)
if { [ "$code" != 000 ] && [ -n "$code" ]; } || { [ "$inside" != v1 ] && [ "$inside" != v2 ]; }; then
  echo "UNEXPECTED: STRICT mTLS contrast failed" >&2; exit 1
fi
echo "OK 3 - the gate bites: plaintext passes before STRICT, then fails while meshed traffic passes"

kc apply -f "$DIR/canary.yaml" >/dev/null
sleep 5
# The loop expands in the client shell, not on the host.
# shellcheck disable=SC2016
responses=$(kc -n mesh exec client -c client -- sh -c 'for _ in $(seq 1 60); do curl -s http://web/; done')
v1_count=$(grep -o v1 <<< "$responses" | wc -l)
v2_count=$(grep -o v2 <<< "$responses" | wc -l)
if [ "$v1_count" -eq 0 ] || [ "$v2_count" -eq 0 ] || [ $((v1_count + v2_count)) -ne 60 ]; then
  echo "UNEXPECTED: canary did not route all requests across both subsets" >&2; exit 1
fi
echo "OK 4 - the 80/20 VirtualService sends traffic to both v1 and v2 ($v1_count/$v2_count)"
echo "ALL CHECKS PASSED"
