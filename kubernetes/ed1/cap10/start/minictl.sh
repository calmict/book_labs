#!/usr/bin/env bash
set -euo pipefail

# minictl - your first controller: observe, diff, act, forever.
# Complete the three TODOs, make it executable, and run it.

DESIRED=2
NAMESPACE=${NAMESPACE:-cap10-lab}

while true; do
  # TODO 1 (10.1): OBSERVE the non-terminating Pods labelled app=minictl in
  # NAMESPACE. The count is the actual state that the controller reconciles.
  OBSERVED=0

  # TODO 2 (10.1): DIFF and ACT when OBSERVED is below DESIRED. Create one
  # labelled Pod in NAMESPACE so each pass moves reality towards the target.

  # TODO 3 (10.1): DIFF and ACT when OBSERVED is above DESIRED. Delete one
  # non-terminating Pod from NAMESPACE so excess state is reconciled too.

  echo "observed $OBSERVED / desired $DESIRED"
  sleep 2
done
