#!/usr/bin/env bash
set -euo pipefail

# Chapter 23 solution test. Contrasts a default root container with a
# restricted SecurityContext, then proves namespace-wide Pod Security
# admission. Uses one throwaway namespace and requires no host privileges.

DIR=$(cd "$(dirname "$0")" && pwd)

command -v kubectl >/dev/null || { echo "ERROR: kubectl is required" >&2; exit 1; }
kubectl get nodes >/dev/null || { echo "ERROR: no reachable cluster" >&2; exit 1; }
echo "PRECHECK cluster reachable; Pod Security admission will be measured"

cleanup() {
  kubectl delete namespace throne --ignore-not-found --wait=true >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

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
king_id=$(kubectl -n throne exec king -- id -u)
king_cap=$(kubectl -n throne exec king -- grep CapEff /proc/self/status | cut -f2)
king_seccomp=$(kubectl -n throne exec king -- grep Seccomp: /proc/self/status | cut -f2)
if [ "$king_id" != 0 ] || [ "$king_cap" = 0000000000000000 ] || [ "$king_seccomp" != 0 ] || ! kubectl -n throne exec king -- sh -c 'echo treasure > /root/proof'; then
  echo "UNEXPECTED: the plain pod does not expose the expected baseline" >&2; exit 1
fi
echo "OK 1 - the plain container is uid 0 with capabilities, no seccomp filter, and writable root"
echo

echo "== 2. Stripping the king (securityContext) =="
kubectl apply -f "$DIR/hardened.yaml" >/dev/null
kubectl -n throne wait --for=condition=Ready pod/hardened --timeout=60s >/dev/null
inspect hardened
hardened_id=$(kubectl -n throne exec hardened -- id -u)
hardened_cap=$(kubectl -n throne exec hardened -- grep CapEff /proc/self/status | cut -f2)
hardened_seccomp=$(kubectl -n throne exec hardened -- grep Seccomp: /proc/self/status | cut -f2)
if [ "$hardened_id" != 65534 ] || [ "$hardened_cap" != 0000000000000000 ] || [ "$hardened_seccomp" != 2 ] || kubectl -n throne exec hardened -- sh -c 'echo treasure > /proof' >/dev/null 2>&1; then
  echo "UNEXPECTED: one or more hardening controls are ineffective" >&2; exit 1
fi
echo "OK 2 - the hardened container is non-root, capability-free, seccomp-filtered, and read-only"
echo

echo "== 3. The checkpoint (Pod Security Standards) =="
kubectl label namespace throne \
  pod-security.kubernetes.io/enforce=restricted --overwrite >/dev/null 2>&1
if [ "$(kubectl -n throne get pod king -o jsonpath='{.status.phase}')" != Running ]; then
  echo "UNEXPECTED: admission policy evicted the existing king" >&2; exit 1
fi
echo "OK 3 - the admission label does not retroactively evict the running king"
echo "trying a NEW root intruder under restricted (expect a refusal):"
if kubectl -n throne run intruder --image=busybox:stable --restart=Never \
     -- sleep infinity >/dev/null 2>&1; then
  echo "  ERROR: the intruder was admitted — PodSecurity is not enforcing" >&2
  echo "  On minikube, the admission plugin is built in and on by default;" >&2
  echo "  if it is off, restricted labels do nothing (chapter 19 deja vu)." >&2
  exit 1
else
  echo "OK 4 - the gate bites: restricted admission refuses a new unprotected root pod"
fi
echo "re-creating the hardened pod under restricted (expect admission):"
kubectl -n throne delete pod hardened --wait=true >/dev/null 2>&1 || true
if kubectl apply -f "$DIR/hardened.yaml" >/dev/null 2>&1; then
  kubectl -n throne wait --for=condition=Ready pod/hardened --timeout=60s >/dev/null
  echo "OK 5 - the restricted SecurityContext is admitted and reaches Running"
else
  echo "  ERROR: the hardened pod was refused — it does not meet restricted" >&2
  exit 1
fi
echo
echo "ALL CHECKS PASSED"
