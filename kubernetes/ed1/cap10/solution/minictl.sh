#!/usr/bin/env bash
set -euo pipefail

# minictl — a twenty-line controller: observe, diff, act, forever.

DESIRED=2

while true; do
  # observe: how many minictl pods exist right now (ignoring dying ones)?
  OBSERVED=$(kubectl get pods -l app=minictl --no-headers 2>/dev/null | grep -cv Terminating || true)

  # diff + act: push reality towards the desired state
  if [ "$OBSERVED" -lt "$DESIRED" ]; then
    echo "observed $OBSERVED < desired $DESIRED: creating one pod"
    kubectl run "minictl-$RANDOM" --labels=app=minictl --image=alpine:3 -- sleep infinity
  elif [ "$OBSERVED" -gt "$DESIRED" ]; then
    # pick a victim that is not already dying
    VICTIM=$(kubectl get pods -l app=minictl --no-headers | grep -v Terminating | awk 'NR==1 {print $1}')
    echo "observed $OBSERVED > desired $DESIRED: deleting $VICTIM"
    kubectl delete pod "$VICTIM" --wait=false
  else
    echo "observed $OBSERVED = desired $DESIRED: nothing to do"
  fi
  sleep 2
done
