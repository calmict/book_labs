#!/usr/bin/env bash
set -euo pipefail

# Chapter 2 — the recipe: imperative provisioning, step by step.
#
# It works perfectly... from ONE starting point: an empty yard. Run it twice
# and watch. Then complete the three TODOs to add the guards and make it
# re-runnable (Phase 1 of the exercise).

echo "step 1: create the fleet directory"
# TODO 1: this step assumes the directory does NOT exist yet, and crashes on
# a second run. Make it survive (hint: mkdir has a flag meaning "and do not
# complain if it is already there").
mkdir fleet

for i in 1 2 3; do
  # TODO 2: this writes the config unconditionally on every run. Write it
  # only when the file does not exist yet, and print
  # "step 2.$i: server-$i already exists, skipping" when you skip
  # (hint: if [ -f "fleet/server-$i.conf" ]; then ... else ... fi).
  echo "step 2.$i: create server-$i"
  printf 'hostname   = server-%s\npackages   = nginx, openssl\nport       = 8080\ndebug_mode = off\n' "$i" > "fleet/server-$i.conf"
done

echo "step 3: register the fleet in the inventory"
# TODO 3: every run APPENDS three more lines to the inventory. Register the
# fleet only once (hint: guard on the existence of fleet/inventory.txt, and
# print "step 3: inventory already exists, skipping" when you skip).
for i in 1 2 3; do
  echo "server-$i registered" >> fleet/inventory.txt
done

echo "done."
