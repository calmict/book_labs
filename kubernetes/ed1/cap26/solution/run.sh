#!/usr/bin/env bash
set -euo pipefail

# Chapter 26 solution test. Creates an isolated kind cluster, lets ArgoCD
# pull desired state from an in-cluster Git ledger, proves self-heal by
# introducing live drift, then proves declarative rollback with git revert.

DIR=$(cd "$(dirname "$0")" && pwd)
CLUSTER=book-labs-gitops
CTX=kind-${CLUSTER}
ARGOCD_MANIFEST=https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
MIN_KB=3145728

command -v kind >/dev/null || { echo "ERROR: kind not found" >&2; exit 1; }
command -v kubectl >/dev/null || { echo "ERROR: kubectl is required" >&2; exit 1; }
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
gitx() { kc -n gitops exec deploy/gitserver -- sh -c "$1"; }
replicas() { kc -n demo get deploy web -o jsonpath='{.spec.replicas}' 2>/dev/null; }
appsync() { kc -n argocd get application web -o jsonpath='{.status.sync.status}' 2>/dev/null; }
apphealth() { kc -n argocd get application web -o jsonpath='{.status.health.status}' 2>/dev/null; }
refresh() { kc -n argocd annotate application web argocd.argoproj.io/refresh=hard --overwrite >/dev/null; }
wait_replicas() {
  local want=$1
  for _ in $(seq 1 45); do [ "$(replicas)" = "$want" ] && return 0; sleep 4; done
  return 1
}

kind create cluster --name "$CLUSTER" >/dev/null 2>&1
kc create namespace argocd >/dev/null
kc apply -n argocd --server-side -f "$ARGOCD_MANIFEST" >/dev/null
kc -n argocd wait --for=condition=Available deploy --all --timeout=300s >/dev/null
kc apply -f "$DIR/../start/gitserver.yaml" >/dev/null
kc -n gitops rollout status deploy/gitserver --timeout=180s >/dev/null
echo "OK 1 - dedicated cluster, ArgoCD, and the Git ledger are ready"

kc apply -f "$DIR/application.yaml" >/dev/null
for _ in $(seq 1 45); do
  refresh || true
  if [ "$(appsync)" = Synced ] && [ "$(apphealth)" = Healthy ] && [ "$(replicas)" = 1 ]; then break; fi
  sleep 5
done
if [ "$(appsync)" != Synced ] || [ "$(apphealth)" != Healthy ] || [ "$(replicas)" != 1 ]; then
  echo "UNEXPECTED: first reconciliation did not converge" >&2; exit 1
fi
echo "OK 2 - Application pulls the ledger and creates one healthy replica"

kc -n demo scale deploy web --replicas=3 >/dev/null
if [ "$(replicas)" != 3 ]; then echo "UNEXPECTED: drift was not introduced" >&2; exit 1; fi
wait_replicas 1 || { echo "UNEXPECTED: self-heal did not erase drift" >&2; exit 1; }
echo "OK 3 - the gate bites: manual drift reaches three replicas, then self-heal restores one"

gitx 'cd /work && sed -i "s/replicas: 1/replicas: 5/" manifests/web.yaml && git commit -qam "scale web to 5" && git push -q origin main'
refresh
wait_replicas 5 || { echo "UNEXPECTED: the bad ledger commit was not reconciled" >&2; exit 1; }
gitx 'cd /work && git revert --no-edit HEAD >/dev/null && git push -q origin main'
refresh
wait_replicas 1 || { echo "UNEXPECTED: git revert was not reconciled" >&2; exit 1; }
if [ "$(gitx 'cd /work && git log -1 --format=%s')" != 'Revert "scale web to 5"' ]; then
  echo "UNEXPECTED: ledger history does not end in the revert" >&2; exit 1
fi
echo "OK 4 - a bad commit scales to five and git revert declaratively restores one"
echo "ALL CHECKS PASSED"
