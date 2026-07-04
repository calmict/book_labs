#!/usr/bin/env bash
set -euo pipefail

# Chapter 23 solution — the cardboard king: root inside a container only
# looks like a king. We inspect its powers, strip them with a
# securityContext, then post a namespace-wide guard (Pod Security
# Standards) that refuses non-compliant pods at admission time.

DIR=$(cd "$(dirname "$0")" && pwd)

kubectl get nodes >/dev/null || {
  echo "ERROR: no reachable cluster — see chapter 7" >&2
  exit 1
}

cleanup() {
  kubectl delete namespace throne --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT
kubectl delete namespace throne --ignore-not-found >/dev/null 2>&1 || true

echo -n "making sure the throne namespace is gone "
waited=0
while kubectl get namespace throne >/dev/null 2>&1; do
  echo -n "."
  sleep 3
  waited=$((waited + 3))
  if [ "$waited" -ge 120 ]; then
    echo " timeout" >&2
    exit 1
  fi
done
echo

kubectl create namespace throne >/dev/null

# the default serviceaccount is provisioned asynchronously; a fresh
# cluster (e.g. a just-started minikube) may not have it yet, and a pod
# cannot be created without it. Wait for it before crowning the king.
waited=0
until kubectl -n throne get serviceaccount default >/dev/null 2>&1; do
  sleep 1
  waited=$((waited + 1))
  if [ "$waited" -ge 30 ]; then
    echo "ERROR: the default serviceaccount never appeared" >&2
    exit 1
  fi
done

inspect() {
  # $1 = pod name
  echo "  id:      $(kubectl -n throne exec "$1" -- id)"
  kubectl -n throne exec "$1" -- sh -c 'grep -E "CapEff|Seccomp:" /proc/self/status' \
    | sed 's/^/  /'
}

echo "== 1. The naked king (no securityContext) =="
kubectl apply -f "$DIR/../start/king.yaml" >/dev/null
kubectl -n throne wait --for=condition=Ready pod/king --timeout=60s >/dev/null
inspect king
if kubectl -n throne exec king -- sh -c 'echo treasure > /root/proof' >/dev/null 2>&1; then
  echo "  root filesystem: WRITABLE"
else
  echo "  root filesystem: read-only (unexpected for the king)" >&2
fi
echo "  (uid 0, CapEff a80425fb — the very number from chapter 4 — Seccomp 0)"
echo

echo "== 2. Stripping the king (securityContext) =="
kubectl apply -f "$DIR/hardened.yaml" >/dev/null
kubectl -n throne wait --for=condition=Ready pod/hardened --timeout=60s >/dev/null
inspect hardened
if kubectl -n throne exec hardened -- sh -c 'echo treasure > /proof' >/dev/null 2>&1; then
  echo "  root filesystem: WRITABLE (the hardening did not take!)" >&2
else
  echo "  root filesystem: read-only (write refused)"
fi
echo "  (uid 65534/nobody, CapEff all zeros, Seccomp 2 — the crown was cardboard)"
echo

echo "== 3. The checkpoint (Pod Security Standards) =="
kubectl label namespace throne \
  pod-security.kubernetes.io/enforce=restricted --overwrite >/dev/null 2>&1
echo "labelled enforce=restricted; the king already running is NOT evicted:"
echo "  king is $(kubectl -n throne get pod king -o jsonpath='{.status.phase}')"
echo "trying a NEW root intruder under restricted (expect a refusal):"
if kubectl -n throne run intruder --image=busybox:stable --restart=Never \
     -- sleep infinity >/dev/null 2>&1; then
  echo "  ERROR: the intruder was admitted — PodSecurity is not enforcing" >&2
  echo "  On minikube, the admission plugin is built in and on by default;" >&2
  echo "  if it is off, restricted labels do nothing (chapter 19 deja vu)." >&2
  exit 1
else
  echo "  intruder REFUSED at admission (as it should be)"
fi
echo "re-creating the hardened pod under restricted (expect admission):"
kubectl -n throne delete pod hardened --wait=true >/dev/null 2>&1 || true
if kubectl apply -f "$DIR/hardened.yaml" >/dev/null 2>&1; then
  kubectl -n throne wait --for=condition=Ready pod/hardened --timeout=60s >/dev/null
  echo "  hardened ADMITTED and Running — defence at scale, one label"
else
  echo "  ERROR: the hardened pod was refused — it does not meet restricted" >&2
  exit 1
fi
echo
echo "=== all three acts passed: the crown was cardboard, the guard is real ==="
