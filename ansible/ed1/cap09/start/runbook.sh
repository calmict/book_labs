#!/usr/bin/env bash
set -euo pipefail

# Chapter 9 — the operator's morning round, written as ad-hoc commands.
# Fill the three TODOs, activate the venv, then run it from this folder:
#   ansible must be on PATH; the copy reads ./motd; pass the inventory as $1.
#   bash runbook.sh inventory.ini
# Run it twice: the copy and file lines should go from yellow CHANGED (first
# run) to green ok / "changed": false (second run) — those modules are switches.

INV="${1:-inventory.ini}"

echo "-- 1. is the fleet up? (ping)"
ansible -i "$INV" web -m ping

echo "-- 2. how long have they been up? (command)"
ansible -i "$INV" web -m command -a 'uptime -p'

# TODO 1: deploy ./motd to /etc/motd on every web host. It writes under /etc, so
# you need root (-b). Use the copy module — an idempotent switch: CHANGED the
# first run, ok the second.
echo "-- 3. deploy the message of the day (copy, as root)"
# ansible -i "$INV" web ...

# TODO 2: ensure the directory /etc/cap09.d exists, owned by root. Use the file
# module with state=directory (and -b, since /etc belongs to root).
echo "-- 4. ensure the app dir exists (file, as root)"
# ansible -i "$INV" web ...

# TODO 3: read ONE fact from each node — the distribution — with the setup
# module and its filter= argument (filter=ansible_distribution).
echo "-- 5. one fact from each node (setup + filter)"
# ansible -i "$INV" web ...
