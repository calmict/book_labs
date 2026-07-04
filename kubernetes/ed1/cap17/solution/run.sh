#!/usr/bin/env bash
set -euo pipefail

# Chapter 17 solution — one per node, until done, on schedule.
# Requires kind and Docker; creates the 3-node book-labs-crew cluster,
# or reuses it if already present.

CLUSTER=book-labs-crew
DIR=$(cd "$(dirname "$0")" && pwd)

KC() { kubectl --context "kind-$CLUSTER" "$@"; }

CREATED=0
PREV_CTX=$(kubectl config current-context 2>/dev/null || true)

cleanup() {
  if [ "$CREATED" -eq 1 ]; then
    kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
    if [ -n "$PREV_CTX" ] && [ "$PREV_CTX" != "kind-$CLUSTER" ]; then
      kubectl config use-context "$PREV_CTX" >/dev/null 2>&1 || true
    fi
  else
    KC delete daemonset watchman --ignore-not-found >/dev/null 2>&1 || true
    KC delete job countdown flaky --ignore-not-found >/dev/null 2>&1 || true
    KC delete cronjob tick --ignore-not-found >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "== 1. Reusing the existing $CLUSTER cluster =="
else
  echo "== 1. Creating the 3-node cluster (control plane + two workers) =="
  kind create cluster --config "$DIR/../start/kind-workers.yaml" --wait 180s
  CREATED=1
fi
KC wait --for=condition=Ready nodes --all --timeout=180s >/dev/null
KC get nodes
KC delete daemonset watchman --ignore-not-found >/dev/null 2>&1 || true
KC delete job countdown flaky --ignore-not-found >/dev/null 2>&1 || true
KC delete cronjob tick --ignore-not-found >/dev/null 2>&1 || true

echo
echo "== 2. One watchman per node (minus the tainted one) =="
KC apply -f "$DIR/watchman.yaml"
KC rollout status daemonset/watchman --timeout=180s >/dev/null
KC get pods -l app=watchman -o wide
COUNT=$(KC get pods -l app=watchman --no-headers | wc -l)
echo "watchmen: $COUNT on 3 nodes (the control plane repels, chapter 11)"
echo "--- the toleration completes the map ---"
KC apply -f "$DIR/watchman-everywhere.yaml"
KC rollout status daemonset/watchman --timeout=180s >/dev/null
KC get pods -l app=watchman -o wide
COUNT=$(KC get pods -l app=watchman --no-headers | wc -l)
if [ "$COUNT" -ne 3 ]; then
  echo "WARNING: expected 3 watchmen, got $COUNT" >&2
fi
echo "--- the geographic contract: rebirth on the SAME node ---"
VICTIM=$(KC get pods -l app=watchman \
  --field-selector spec.nodeName="$CLUSTER-worker" -o jsonpath='{.items[0].metadata.name}')
KC delete pod "$VICTIM" >/dev/null
KC rollout status daemonset/watchman --timeout=180s >/dev/null
KC get pods -l app=watchman \
  --field-selector spec.nodeName="$CLUSTER-worker" -o wide
echo "(a new watchman, same post: not a count to restore, a map to honour)"

echo
echo "== 3. Until done (and the right to fail) =="
KC apply -f "$DIR/jobs.yaml"
KC wait --for=condition=complete job/countdown --timeout=180s >/dev/null
echo "--- countdown: Completed, with the receipt in the logs ---"
KC get job countdown
KC logs job/countdown | tail -3
echo "--- flaky: retries, then gives up with honesty ---"
KC wait --for=condition=failed job/flaky --timeout=240s >/dev/null
KC get pods -l job-name=flaky
ATTEMPTS=$(KC get pods -l job-name=flaky --no-headers | wc -l)
echo "attempts: $ATTEMPTS (1 try + backoffLimit 2)"
KC describe job flaky | grep -E 'BackoffLimitExceeded' | head -1

echo
echo "== 4. On schedule: waiting for the minute hand =="
KC apply -f "$DIR/tick.yaml"
echo -n "waiting for the first tick (up to ~90s) "
waited=0
TICKJOB=""
until [ -n "$TICKJOB" ]; do
  TICKJOB=$(KC get jobs -o name 2>/dev/null | grep 'job.batch/tick-' | head -1 || true)
  if [ -z "$TICKJOB" ]; then
    echo -n "."
    sleep 5
    waited=$((waited + 5))
    if [ "$waited" -ge 150 ]; then
      echo " timeout" >&2
      exit 1
    fi
  fi
done
echo
KC wait --for=condition=complete "$TICKJOB" --timeout=120s >/dev/null
KC get jobs
KC logs "$TICKJOB"
echo "(CronJob -> Job -> Pod: chapter 13's delegation, one floor taller)"
