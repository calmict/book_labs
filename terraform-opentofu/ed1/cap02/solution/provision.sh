#!/usr/bin/env bash
set -euo pipefail

# Chapter 2 solution — the recipe with the guards: hand-made idempotence.
#
# Re-runnable: every step first checks whether its work is already done.
# Note the cost: the script nearly doubled, every resource carries its own
# guard — and the guards check EXISTENCE, not CONTENT. A hand-vandalised
# config walks past them undisturbed (that is Phase 2 of the exercise, and
# it is the point: re-runnable does not mean convergent).

echo "step 1: create the fleet directory (if missing)"
mkdir -p fleet

for i in 1 2 3; do
  if [ -f "fleet/server-$i.conf" ]; then
    echo "step 2.$i: server-$i already exists, skipping"
  else
    echo "step 2.$i: create server-$i"
    printf 'hostname   = server-%s\npackages   = nginx, openssl\nport       = 8080\ndebug_mode = off\n' "$i" > "fleet/server-$i.conf"
  fi
done

if [ -f fleet/inventory.txt ]; then
  echo "step 3: inventory already exists, skipping"
else
  echo "step 3: register the fleet in the inventory"
  for i in 1 2 3; do
    echo "server-$i registered" >> fleet/inventory.txt
  done
fi

echo "done."
