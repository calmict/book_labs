#!/usr/bin/env bash
set -euo pipefail

# Chapter 28 solution — the doorman's passport: automatic HTTPS with
# Ingress-Nginx and cert-manager. We build a local CA, then a single Ingress
# annotation makes cert-manager issue and store a certificate the doorman
# serves over HTTPS — validated against our CA. Runs on a dedicated throwaway
# kind cluster (ingress-nginx and cert-manager install cluster-wide).

DIR=$(cd "$(dirname "$0")" && pwd)
CLUSTER=book-labs-tls
CTX=kind-${CLUSTER}
INGRESS_MANIFEST=https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.0/deploy/static/provider/kind/deploy.yaml
CERTMANAGER_MANIFEST=https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml

command -v kind >/dev/null || { echo "ERROR: kind not found" >&2; exit 1; }

PREV_CTX=$(kubectl config current-context 2>/dev/null || true)
cleanup() {
  kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
  if [ -n "$PREV_CTX" ]; then
    kubectl config use-context "$PREV_CTX" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

kc() { kubectl --context "$CTX" "$@"; }

echo "== 0. A dedicated cluster, the doorman and the passport office =="
kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
kind create cluster --name "$CLUSTER" >/dev/null 2>&1
kc label node "${CLUSTER}-control-plane" ingress-ready=true >/dev/null
kc apply -f "$INGRESS_MANIFEST" >/dev/null 2>&1
kc apply -f "$CERTMANAGER_MANIFEST" >/dev/null 2>&1
echo -n "  waiting for ingress-nginx and cert-manager "
kc -n ingress-nginx wait --for=condition=Available deploy/ingress-nginx-controller --timeout=240s >/dev/null
kc -n cert-manager wait --for=condition=Available deploy --all --timeout=240s >/dev/null
echo "ready"

echo "== 1. Build the local authority (SelfSigned -> CA -> CA issuer) =="
kc apply -f "$DIR/../start/issuer.yaml" >/dev/null
kc -n cert-manager wait --for=condition=Ready certificate/local-ca --timeout=90s >/dev/null
echo "  local CA ready (in production this authority would be Let's Encrypt via ACME)"
echo

echo "== 2. One annotation asks for a passport (automatic certificate) =="
kc apply -f "$DIR/../start/app.yaml" >/dev/null
kc -n web rollout status deploy/shop --timeout=90s >/dev/null
# the ingress-nginx admission webhook can refuse connections for a few
# seconds after the controller is Available (chapter 19: rules before the
# controller is really ready) — retry until the Ingress is accepted.
for _ in $(seq 1 30); do
  if kc apply -f "$DIR/ingress.yaml" >/dev/null 2>&1; then break; fi
  sleep 3
done
kc apply -f "$DIR/ingress.yaml" >/dev/null
echo -n "  waiting for cert-manager to issue shop-tls "
kc -n web wait --for=condition=Ready certificate/shop-tls --timeout=120s >/dev/null
echo "issued"
kc -n web get certificate shop-tls -o custom-columns='CERT:.metadata.name,READY:.status.conditions[0].status,SECRET:.spec.secretName' | sed 's/^/  /'
echo "  (you generated no key and no certificate — the office did)"
echo

echo "== 3. The visitor checks the passport (HTTPS, validated against our CA) =="
kc -n web wait --for=condition=Ready pod/tlsclient --timeout=90s >/dev/null
ip=$(kc -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.clusterIP}')
echo -n "  https://shop.book-labs.local/ -> "
kc -n web exec tlsclient -- \
  curl -sS --cacert /ca/ca.crt --resolve "shop.book-labs.local:443:$ip" \
  https://shop.book-labs.local/
echo "  the served certificate (no -k needed — trusted by our CA):"
kc -n web get secret shop-tls -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -noout -issuer -ext subjectAltName 2>/dev/null | sed 's/^/    /'
echo
echo "=== HTTPS end-to-end: issued, served and renewed with no hand-made certs ==="
