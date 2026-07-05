#!/usr/bin/env bash
set -euo pipefail

# Chapter 26 solution — the ledger and the auditor: GitOps with ArgoCD.
# Git (an in-cluster git server) holds the desired state; ArgoCD makes the
# cluster match it, corrects manual drift (self-heal), and rolls back when
# the ledger is corrected with git revert. Runs on a dedicated throwaway
# kind cluster, because ArgoCD installs cluster-wide CRDs and roles.

DIR=$(cd "$(dirname "$0")" && pwd)
CLUSTER=book-labs-gitops
CTX=kind-${CLUSTER}
ARGOCD_MANIFEST=https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

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
gitx() { kc -n gitops exec deploy/gitserver -- sh -c "$1"; }
replicas() { kc -n demo get deploy web -o jsonpath='{.spec.replicas}' 2>/dev/null; }
appsync() { kc -n argocd get application web -o jsonpath='{.status.sync.status}' 2>/dev/null; }
apphealth() { kc -n argocd get application web -o jsonpath='{.status.health.status}' 2>/dev/null; }
refresh() { kc -n argocd annotate application web argocd.argoproj.io/refresh=hard --overwrite >/dev/null; }

# wait until web has the given replica count (and give up after ~2 min)
wait_replicas() {
  local want=$1
  for _ in $(seq 1 30); do
    [ "$(replicas)" = "$want" ] && return 0
    sleep 4
  done
  echo "  timeout waiting for web to reach $want replicas" >&2
  return 1
}

echo "== 0. The building site: a dedicated cluster + ArgoCD =="
kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
kind create cluster --name "$CLUSTER" >/dev/null 2>&1
echo "  cluster $CLUSTER created"
kc create namespace argocd >/dev/null
# --server-side avoids the "annotation too long" error on ArgoCD's largest CRD
kc apply -n argocd --server-side -f "$ARGOCD_MANIFEST" >/dev/null 2>&1 || true
echo -n "  waiting for ArgoCD to come up "
kc -n argocd wait --for=condition=Available deploy --all --timeout=300s >/dev/null
echo "ready"
kc apply -f "$DIR/../start/gitserver.yaml" >/dev/null
kc -n gitops rollout status deploy/gitserver --timeout=120s >/dev/null
echo "  ledger online: git://gitserver.gitops.svc:9418/app.git (web at 1 replica)"
echo

echo "== 1-2. The auditor's assignment (Application) =="
kc apply -f "$DIR/application.yaml" >/dev/null
# force an immediate comparison instead of waiting for the ~3min poll
sleep 3
refresh
echo -n "  waiting for the first sync "
for _ in $(seq 1 40); do
  if [ "$(appsync)" = "Synced" ] && [ "$(apphealth)" = "Healthy" ]; then break; fi
  echo -n "."
  sleep 5
  refresh
done
echo
echo "  application: sync=$(appsync) health=$(apphealth)"
echo "  web in demo: $(replicas) replica (created by ArgoCD, not by hand)"
echo

echo "== 3. The auditor never sleeps (drift and self-heal) =="
kc -n demo scale deploy web --replicas=3 >/dev/null
echo "  scaled web to 3 by hand; sync is now $(appsync)"
wait_replicas 1
echo "  self-healed back to $(replicas) replica — the world does not rule, the ledger does"
echo

echo "== 4. Correct the ledger, not the world (git revert) =="
gitx 'cd /work && sed -i "s/replicas: 1/replicas: 5/" manifests/web.yaml && git commit -qam "scale web to 5 (oops)" && git push -q origin main'
refresh
echo "  a bad commit set replicas to 5 in the ledger..."
wait_replicas 5
echo "  ArgoCD obeyed the ledger: web is at $(replicas) (the book is law, even when wrong)"
gitx 'cd /work && git revert --no-edit HEAD >/dev/null && git push -q origin main'
refresh
echo "  git revert struck the line out; the auditor propagates it..."
wait_replicas 1
echo "  web back to $(replicas) replica — a declarative rollback, signed in git history:"
gitx 'cd /work && git log --oneline -3' | sed 's/^/    /'
echo
echo "=== the ledger is the source of truth; the auditor keeps the world honest ==="
