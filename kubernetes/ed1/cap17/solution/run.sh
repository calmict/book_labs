#!/usr/bin/env bash
set -euo pipefail

# Chapter 17 solution: one Pod per eligible node, finite work with retry,
# and scheduled work. Uses a dedicated disposable three-node kind cluster.

CLUSTER=book-labs-crew
NS=book-labs-cap17
DIR=$(cd "$(dirname "$0")" && pwd)
CREATED=0
PREV_CTX=$(kubectl config current-context 2>/dev/null || true)

KC() { kubectl --context "kind-$CLUSTER" "$@"; }

cleanup() {
  if [ "$CREATED" -eq 1 ]; then
    kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
  else
    KC delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  fi
  if [ -n "$PREV_CTX" ] && [ "$PREV_CTX" != "kind-$CLUSTER" ]; then
    kubectl config use-context "$PREV_CTX" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind export kubeconfig --name "$CLUSTER" >/dev/null 2>&1
  echo "PRECHECK reusing $CLUSTER after exporting its kubeconfig"
else
  docker_root=$(docker info --format '{{.DockerRootDir}}')
  free_kb=$(df -Pk "$docker_root" | awk 'NR==2 {print $4}')
  required_kb=$((3 * 1024 * 1024))
  if [ "$free_kb" -lt "$required_kb" ]; then
    free_gb=$((free_kb / 1024 / 1024))
    echo "SKIP 1 - a dedicated three-node cluster needs 3 GB free; Docker has ${free_gb} GB."
    echo "ALL CHECKS PASSED"
    exit 0
  fi
  echo "PRECHECK Docker has at least 3 GB free for the dedicated cluster"
  kind create cluster --config "$DIR/../start/kind-workers.yaml" --wait 180s
  CREATED=1
fi
KC wait --for=condition=Ready nodes --all --timeout=180s >/dev/null
KC delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
KC create namespace "$NS" >/dev/null
nodes=$(KC get nodes --no-headers | wc -l)
if [ "$nodes" -ne 3 ]; then
  echo "ERROR: expected three nodes, got $nodes" >&2
  exit 1
fi
echo "OK 1 - the dedicated cluster has one control plane and two workers"

KC -n "$NS" apply -f "$DIR/watchman.yaml" >/dev/null
KC -n "$NS" rollout status daemonset/watchman --timeout=180s >/dev/null
before=$(KC -n "$NS" get daemonset watchman -o jsonpath='{.status.numberReady}')
if [ "$before" -ne 2 ]; then
  echo "ERROR: expected two watchmen before the toleration, got $before" >&2
  exit 1
fi
echo "OK 2 - without the toleration the control-plane taint keeps one post empty"

KC -n "$NS" apply -f "$DIR/watchman-everywhere.yaml" >/dev/null
KC -n "$NS" rollout status daemonset/watchman --timeout=180s >/dev/null
after=$(KC -n "$NS" get daemonset watchman -o jsonpath='{.status.numberReady}')
if [ "$after" -ne 3 ]; then
  echo "ERROR: expected three watchmen after the toleration, got $after" >&2
  exit 1
fi
echo "OK 3 - the toleration expands the DaemonSet map to all three nodes"

worker="$CLUSTER-worker"
victim=$(KC -n "$NS" get pods -l app=watchman --field-selector spec.nodeName="$worker" -o jsonpath='{.items[0].metadata.name}')
KC -n "$NS" delete pod "$victim" --wait=true >/dev/null
KC -n "$NS" rollout status daemonset/watchman --timeout=180s >/dev/null
replacement=$(KC -n "$NS" get pods -l app=watchman --field-selector spec.nodeName="$worker" -o jsonpath='{.items[0].metadata.name}')
if [ "$replacement" = "$victim" ]; then
  echo "ERROR: DaemonSet Pod was not recreated" >&2
  exit 1
fi
echo "OK 4 - a deleted watchman returned to the same node with a new Pod identity"

KC -n "$NS" apply -f "$DIR/jobs.yaml" >/dev/null
KC -n "$NS" wait --for=condition=complete job/countdown --timeout=180s >/dev/null
KC -n "$NS" wait --for=condition=failed job/flaky --timeout=240s >/dev/null
attempts=$(KC -n "$NS" get pods -l job-name=flaky --no-headers | wc -l)
reason=$(KC -n "$NS" get job flaky -o jsonpath='{.status.conditions[?(@.type=="Failed")].reason}')
if [ "$attempts" -ne 3 ] || [ "$reason" != BackoffLimitExceeded ]; then
  echo "ERROR: flaky did not record three attempts and BackoffLimitExceeded" >&2
  exit 1
fi
echo "OK 5 - countdown completed while flaky stopped after three failed Pods"

KC -n "$NS" apply -f "$DIR/tick.yaml" >/dev/null
waited=0
tick_job=
until [ -n "$tick_job" ]; do
  tick_job=$(KC -n "$NS" get jobs -o name | grep 'job.batch/tick-' | head -1 || true)
  if [ -z "$tick_job" ]; then
    sleep 5
    waited=$((waited + 5))
    if [ "$waited" -ge 150 ]; then
      echo "ERROR: CronJob did not create a Job" >&2
      exit 1
    fi
  fi
done
KC -n "$NS" wait --for=condition=complete "$tick_job" --timeout=120s >/dev/null
if ! KC -n "$NS" logs "$tick_job" | grep -q '^tick at '; then
  echo "ERROR: scheduled Job did not print its timestamp" >&2
  exit 1
fi
echo "OK 6 - CronJob created a Job and Pod that completed with a timestamp"
echo "ALL CHECKS PASSED"
