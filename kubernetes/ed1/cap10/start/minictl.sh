#!/usr/bin/env bash
set -euo pipefail

# minictl — your first controller: observe, diff, act, forever.
# Complete the three TODOs, make it executable, run it. Nothing else needed.

DESIRED=2

while true; do
  # TODO 1 — OBSERVE: count the pods labelled app=minictl that are not
  # Terminating. Hint: kubectl get pods -l app=minictl --no-headers
  OBSERVED=0

  # TODO 2 — DIFF + ACT (too few): if OBSERVED is below DESIRED, create one:
  # kubectl run "minictl-$RANDOM" --labels=app=minictl --image=alpine:3 -- sleep infinity

  # TODO 3 — DIFF + ACT (too many): if OBSERVED is above DESIRED, delete one.

  echo "observed $OBSERVED / desired $DESIRED"
  sleep 2
done
