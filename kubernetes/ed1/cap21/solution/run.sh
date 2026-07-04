#!/usr/bin/env bash
set -euo pipefail

# Chapter 21 solution — the intern and the robot: real authentication via
# the CSR API, least-privilege RBAC, and a pod calling the API with its
# own identity. Pure API exercise; needs openssl on the host.

DIR=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/lab-cap21.XXXXXX")
SK() { kubectl --kubeconfig "$WORK/stagista.kubeconfig" "$@"; }

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}
command -v openssl >/dev/null || {
  echo "ERROR: openssl not found on the host" >&2
  exit 1
}

cleanup() {
  kubectl delete -f "$DIR/rbac.yaml" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete -f "$DIR/robot.yaml" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete -f "$DIR/robot-binding.yaml" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete csr stagista --ignore-not-found >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT
cleanup
WORK=$(mktemp -d "${TMPDIR:-/tmp}/lab-cap21.XXXXXX")

echo "== 1. Who you are today =="
kubectl auth whoami

echo
echo "== 2. The hiring: key, CSR, the cluster CA's signature =="
openssl genrsa -out "$WORK/stagista.key" 2048 2>/dev/null
openssl req -new -key "$WORK/stagista.key" \
  -subj "/CN=stagista/O=tirocinanti" -out "$WORK/stagista.csr"
kubectl apply -f - <<REQUEST
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: stagista
spec:
  request: $(base64 -w0 < "$WORK/stagista.csr")
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages: ["client auth"]
REQUEST
kubectl certificate approve stagista
echo -n "waiting for the signed certificate "
waited=0
until [ -n "$(kubectl get csr stagista -o jsonpath='{.status.certificate}' 2>/dev/null)" ]; do
  echo -n "."
  sleep 2
  waited=$((waited + 2))
  if [ "$waited" -ge 60 ]; then
    echo " timeout" >&2
    exit 1
  fi
done
echo
kubectl get csr stagista -o jsonpath='{.status.certificate}' | base64 -d > "$WORK/stagista.crt"
echo "(note: no User object was created anywhere — the intern exists only"
echo " in this certificate: CN is the name, O the groups)"

echo
echo "== 3. Her own kubeconfig, and the closed second gate =="
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
# inline data on kind, a file path on minikube (chapter 9's lesson)
CADATA=$(kubectl config view --raw --minify \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
if [ -n "$CADATA" ]; then
  base64 -d <<< "$CADATA" > "$WORK/ca.crt"
else
  cp "$(kubectl config view --raw --minify \
    -o jsonpath='{.clusters[0].cluster.certificate-authority}')" "$WORK/ca.crt"
fi
SK config set-cluster lab --server "$SERVER" \
  --certificate-authority "$WORK/ca.crt" --embed-certs >/dev/null
SK config set-credentials stagista --client-certificate "$WORK/stagista.crt" \
  --client-key "$WORK/stagista.key" --embed-certs >/dev/null
SK config set-context stagista --cluster lab --user stagista >/dev/null
SK config use-context stagista >/dev/null
SK auth whoami
set +e
OUT=$(SK get pods 2>&1)
set -e
echo "$OUT" | tail -1
if grep -q Forbidden <<< "$OUT"; then
  echo "(authenticated, and rejected: hired, but with no duties yet)"
else
  echo "WARNING: expected Forbidden before any Role" >&2
fi

echo
echo "== 4. The minimal duties, and their borders =="
kubectl apply -f "$DIR/rbac.yaml"
sleep 2
echo "--- get pods (allowed) ---"
SK get pods
echo "--- everything else (three walls) ---"
set +e
SK run test --image=alpine:3 2>&1 | tail -1
SK get secrets 2>&1 | tail -1
SK get pods -n kube-system 2>&1 | tail -1
set -e
echo "--- the whole job description ---"
JOBDESC=$(SK auth can-i --list)
head -6 <<< "$JOBDESC"

echo
echo "== 5. The robot: an identity for a workload =="
kubectl apply -f "$DIR/robot.yaml"
kubectl wait --for=condition=Ready pod/robot --timeout=180s >/dev/null
# shellcheck disable=SC2016  # the token must expand inside the pod's shell
APICALL='curl -s --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://kubernetes.default.svc/api/v1/namespaces/default/pods'
echo "--- from inside the pod, BEFORE any binding ---"
BEFORE=$(kubectl exec robot -- sh -c "$APICALL")
grep -E '"code"|"reason"' <<< "$BEFORE" || echo "$BEFORE" | head -3
echo "--- the binding, applied last ---"
kubectl apply -f "$DIR/robot-binding.yaml"
sleep 3
AFTER=$(kubectl exec robot -- sh -c "$APICALL")
if grep -q '"kind": "PodList"' <<< "$AFTER"; then
  echo "(a PodList: the robot reads the pods with its own mounted token —"
  echo " chapter 9 seen from inside the workload)"
else
  echo "WARNING: expected a PodList after the binding" >&2
  echo "$AFTER" | head -5
fi
