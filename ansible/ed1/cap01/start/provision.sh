#!/usr/bin/env bash
set -euo pipefail

# Chapter 1 — the hand-written provisioning script (starting point).
#
# Desired state on every server:
#   - the service user 'app' exists
#   - /etc/app.conf contains exactly: version=1.0
#
# The servers already exist (see Phase 0 in the README). Run this once: it works.
# Run it a SECOND time and watch it break (crack 1). Then complete the two TODOs.

SERVERS=(cap01-server1 cap01-server2 cap01-server3)

for s in "${SERVERS[@]}"; do

  # ---- user 'app' ----
  # Naive: just order the creation. On the second run this fails with
  #   useradd: user 'app' already exists
  # TODO 1: guard it so the command runs only when the user is missing, e.g.
  #   docker exec "$s" sh -c 'id -u app >/dev/null 2>&1 || useradd app'
  docker exec "$s" useradd app

  # ---- /etc/app.conf ----
  # TODO 1: the "obvious" guard is to skip the write if the file already exists:
  #   docker exec "$s" sh -c 'test -f /etc/app.conf || echo "version=1.0" > /etc/app.conf'
  # Try that guard, then inject drift on one server (see Phase 3 in the README)
  # and re-run: the drift SURVIVES, because the guard checks existence, not content.
  # TODO 2: make it converge — enforce the desired CONTENT on every run:
  #   docker exec "$s" sh -c 'echo "version=1.0" > /etc/app.conf'
  docker exec "$s" sh -c 'echo "version=1.0" > /etc/app.conf'

done

echo "provisioned: ${SERVERS[*]}"
