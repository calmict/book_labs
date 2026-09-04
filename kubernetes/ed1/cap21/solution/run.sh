#!/usr/bin/env bash
# Chapter 21 - solution test. Creates a short-lived client certificate,
# proves least-privilege Role boundaries, and contrasts a workload API call
# before and after its ServiceAccount binding. Uses an isolated namespace and
# removes the cluster-scoped CSR as well as every namespaced object.
set -euo pipefail

DIR=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/lab-cap21.XXXXXX")
NS=lab-cap21
CSR=cap21-stagista
SK() { kubectl --kubeconfig "$WORK/stagista.kubeconfig" "$@"; }

cleanup() {
  kubectl delete csr "$CSR" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

command -v kubectl >/dev/null || { echo "ERROR: kubectl is required" >&2; exit 1; }
command -v openssl >/dev/null || { echo "ERROR: openssl is required" >&2; exit 1; }
kubectl get nodes >/dev/null || { echo "ERROR: no reachable cluster" >&2; exit 1; }
echo "PRECHECK cluster reachable and openssl available"

cleanup
WORK=$(mktemp -d "${TMPDIR:-/tmp}/lab-cap21.XXXXXX")
kubectl create namespace "$NS" >/dev/null

openssl genrsa -out "$WORK/stagista.key" 2048 2>/dev/null
openssl req -new -key "$WORK/stagista.key" -subj "/CN=stagista/O=tirocinanti" -out "$WORK/stagista.csr"
request=$(base64 -w0 < "$WORK/stagista.csr")
kubectl apply -f - >/dev/null <<REQUEST
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $CSR
spec:
  request: $request
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages: ["client auth"]
REQUEST
kubectl certificate approve "$CSR" >/dev/null
waited=0
until [ -n "$(kubectl get csr "$CSR" -o jsonpath='{.status.certificate}' 2>/dev/null)" ]; do
  sleep 2
  waited=$((waited + 2))
  if [ "$waited" -ge 60 ]; then echo "timeout waiting for signed certificate" >&2; exit 1; fi
done
kubectl get csr "$CSR" -o jsonpath='{.status.certificate}' | base64 -d > "$WORK/stagista.crt"

server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
ca_data=$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
if [ -n "$ca_data" ]; then
  printf '%s' "$ca_data" | base64 -d > "$WORK/ca.crt"
else
  ca_file=$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority}')
  cp "$ca_file" "$WORK/ca.crt"
fi
SK config set-cluster lab --server "$server" --certificate-authority "$WORK/ca.crt" --embed-certs >/dev/null
SK config set-credentials stagista --client-certificate "$WORK/stagista.crt" --client-key "$WORK/stagista.key" --embed-certs >/dev/null
SK config set-context stagista --cluster lab --user stagista --namespace "$NS" >/dev/null
SK config use-context stagista >/dev/null
identity=$(SK auth whoami -o jsonpath='{.status.userInfo.username}')
groups=$(SK auth whoami -o jsonpath='{.status.userInfo.groups[*]}')
if [ "$identity" != "stagista" ] || ! grep -qw tirocinanti <<< "$groups"; then
  echo "UNEXPECTED: certificate identity is $identity with groups $groups" >&2
  exit 1
fi
echo "OK 1 - the signed certificate authenticates stagista in the tirocinanti group"

if SK get pods >/dev/null 2>&1; then
  echo "UNEXPECTED: stagista can read pods before receiving a RoleBinding" >&2
  exit 1
fi
echo "OK 2 - the gate bites: authentication alone grants no permission to read pods"

kubectl apply -f "$DIR/rbac.yaml" >/dev/null
if ! SK auth can-i get pods | grep -qx yes; then
  echo "UNEXPECTED: stagista cannot get pods after the RoleBinding" >&2
  exit 1
fi
echo "OK 3 - the RoleBinding grants get/list/watch on pods in lab-cap21"

if SK auth can-i create pods | grep -qx yes || SK auth can-i list secrets | grep -qx yes || SK auth can-i get pods -n kube-system | grep -qx yes; then
  echo "UNEXPECTED: the Role crossed a verb, resource, or namespace boundary" >&2
  exit 1
fi
echo "OK 4 - create pods, list secrets, and cross-namespace pod access remain denied"

kubectl apply -f "$DIR/robot.yaml" >/dev/null
kubectl -n "$NS" wait --for=condition=Ready pod/robot --timeout=180s >/dev/null
# shellcheck disable=SC2016
api_call='curl -s --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://kubernetes.default.svc/api/v1/namespaces/lab-cap21/pods'
before=$(kubectl -n "$NS" exec robot -- sh -c "$api_call")
if ! grep -q '"code": 403' <<< "$before"; then
  echo "UNEXPECTED: robot did not receive 403 before its binding" >&2
  exit 1
fi
echo "OK 5 - the gate bites: the robot ServiceAccount receives 403 before its binding"

kubectl apply -f "$DIR/robot-binding.yaml" >/dev/null
after=$(kubectl -n "$NS" exec robot -- sh -c "$api_call")
if ! grep -q '"kind": "PodList"' <<< "$after"; then
  echo "UNEXPECTED: robot did not receive a PodList after its binding" >&2
  exit 1
fi
echo "OK 6 - the mounted ServiceAccount token returns a PodList after binding"

echo
echo "ALL CHECKS PASSED"
