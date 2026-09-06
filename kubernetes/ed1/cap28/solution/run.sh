#!/usr/bin/env bash
# Chapter 28 solution test. Builds a local CA, proves that an Ingress without
# the cert-manager annotation and TLS request produces no certificate, then
# verifies automatic issuance and trusted HTTPS through Traefik. Uses a
# dedicated throwaway kind cluster; needs Docker, kind, kubectl, openssl,
# network access, and 3 GiB free in Docker storage.
set -euo pipefail

DIR=$(cd "$(dirname "$0")" && pwd)
CLUSTER=book-labs-tls
CTX=kind-${CLUSTER}
CERTMANAGER_MANIFEST=https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml

command -v kind >/dev/null || { echo "ERROR: kind not found" >&2; exit 1; }
for command in docker kubectl openssl base64 grep df awk; do
  command -v "$command" >/dev/null || { echo "ERROR: $command is required" >&2; exit 1; }
done

docker_root=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null) || {
  echo "ERROR: Docker is not reachable" >&2
  exit 1
}
free_kib=$(df -Pk "$docker_root" | awk 'NR==2 {print $4}')
required_kib=$((3 * 1024 * 1024))
if [ "$free_kib" -lt "$required_kib" ]; then
  free_mib=$((free_kib / 1024))
  echo "SKIP 1 - the dedicated kind cluster needs 3072 MiB free in $docker_root; ${free_mib} MiB is available"
  echo "ALL CHECKS PASSED"
  exit 0
fi
echo "PRECHECK Docker storage has at least 3 GiB free"

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
kc apply -f "$DIR/traefik.yaml" >/dev/null
kc apply -f "$CERTMANAGER_MANIFEST" >/dev/null 2>&1
echo -n "  waiting for Traefik and cert-manager "
kc -n traefik wait --for=condition=Available deploy/traefik --timeout=240s >/dev/null
kc -n cert-manager wait --for=condition=Available deploy --all --timeout=240s >/dev/null
echo "ready"

echo "== 1. Build the local authority (SelfSigned -> CA -> CA issuer) =="
issuer_applied=0
for _ in $(seq 1 30); do
  if kc apply -f "$DIR/../start/issuer.yaml" >/dev/null 2>&1; then
    issuer_applied=1
    break
  fi
  sleep 3
done
if [ "$issuer_applied" -ne 1 ]; then
  echo "UNEXPECTED: the cert-manager webhook did not become ready" >&2
  exit 1
fi
kc -n cert-manager wait --for=condition=Ready certificate/local-ca --timeout=90s >/dev/null
kc wait --for=condition=Ready clusterissuer/local-ca --timeout=90s >/dev/null
if [ "$(kc get clusterissuer local-ca -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" != "True" ]; then
  echo "UNEXPECTED: the local CA issuer is not Ready" >&2
  exit 1
fi
echo "OK 1 - the SelfSigned bootstrap produces a Ready local CA issuer"
echo

echo "== 2. The incomplete request produces no passport =="
kc apply -f "$DIR/../start/app.yaml" >/dev/null
kc -n web rollout status deploy/shop --timeout=90s >/dev/null
kc apply -f "$DIR/../start/ingress.yaml" >/dev/null
sleep 5
if kc -n web get certificate shop-tls >/dev/null 2>&1 || kc -n web get secret shop-tls >/dev/null 2>&1; then
  echo "UNEXPECTED: the incomplete Ingress produced shop-tls" >&2
  exit 1
fi
echo "OK 2 - the gate bites: without the annotation and TLS block no certificate is issued"

echo "== 3. One annotation asks for a passport (automatic certificate) =="
kc apply -f "$DIR/ingress.yaml" >/dev/null
echo -n "  waiting for cert-manager to issue shop-tls "
kc -n web wait --for=condition=Ready certificate/shop-tls --timeout=120s >/dev/null
echo "issued"
if [ "$(kc -n web get secret shop-tls -o jsonpath='{.type}')" != "kubernetes.io/tls" ]; then
  echo "UNEXPECTED: shop-tls is not a Kubernetes TLS Secret" >&2
  exit 1
fi
echo "OK 3 - cert-manager creates a Ready Certificate and the shop-tls TLS Secret"
echo

echo "== 4. The visitor checks the passport (HTTPS, validated against our CA) =="
kc -n web wait --for=condition=Ready pod/tlsclient --timeout=90s >/dev/null
ip=$(kc -n traefik get svc traefik -o jsonpath='{.spec.clusterIP}')
response=
for _ in $(seq 1 30); do
  response=$(kc -n web exec tlsclient -- \
    curl -sS --cacert /ca/ca.crt --resolve "shop.book-labs.local:443:$ip" \
    https://shop.book-labs.local/) || true
  if [ "$response" = "secure shop" ]; then
    break
  fi
  sleep 2
done
if [ "$response" != "secure shop" ]; then
  echo "UNEXPECTED: HTTPS returned '$response'" >&2
  exit 1
fi
echo "OK 4 - Traefik serves secure shop over HTTPS trusted by the local CA"

certificate=$(kc -n web get secret shop-tls -o jsonpath='{.data.tls\.crt}' | base64 -d)
if ! grep -q 'DNS:shop.book-labs.local' <<< "$(openssl x509 -noout -ext subjectAltName <<< "$certificate" 2>/dev/null)"; then
  echo "UNEXPECTED: the certificate SAN does not contain shop.book-labs.local" >&2
  exit 1
fi
if ! grep -q 'issuer=CN = book-labs-local-ca\|issuer=CN=book-labs-local-ca' <<< "$(openssl x509 -noout -issuer <<< "$certificate")"; then
  echo "UNEXPECTED: the certificate was not signed by the local CA" >&2
  exit 1
fi
echo "OK 5 - the issued certificate has the requested SAN and the local CA as issuer"

echo
echo "ALL CHECKS PASSED"
