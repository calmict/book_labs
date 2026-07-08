#!/usr/bin/env bash
set -euo pipefail

# Chapter 1 — the converging form of the hand-written script.
#
# It does NOT create the servers (that is the lab's job, see Phase 0 in the
# README); it enforces the desired state on servers that already exist, and it
# CONVERGES: whatever the starting point, each server ends up with the user 'app'
# and /etc/app.conf == version=1.0. Run it as many times as you like.

SERVERS=(cap01-server1 cap01-server2 cap01-server3)

for s in "${SERVERS[@]}"; do
  # user: create it only when missing — repeatable
  docker exec "$s" sh -c 'id -u app >/dev/null 2>&1 || useradd app'
  # config: enforce the desired content every run — convergent by construction
  docker exec "$s" sh -c 'echo "version=1.0" > /etc/app.conf'
  echo "  $s: user app present, /etc/app.conf -> version=1.0"
done
