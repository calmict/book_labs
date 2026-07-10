#!/usr/bin/env bash
set -euo pipefail

# Chapter 9 solution — the operator's morning round, as ad-hoc commands.
# Run it from a folder holding the inventory and the motd file, with ansible on
# PATH (the venv active):
#   bash runbook.sh inventory.ini
# The copy and file lines are switches: CHANGED on the first run, ok on the
# second. ping, command and setup report on the fleet without changing it.

INV="${1:-inventory.ini}"

echo "-- 1. is the fleet up? (ping)"
ansible -i "$INV" web -m ping

echo "-- 2. how long have they been up? (command)"
ansible -i "$INV" web -m command -a 'uptime -p'

echo "-- 3. deploy the message of the day (copy, as root)"
ansible -i "$INV" web -b -m copy -a 'src=motd dest=/etc/motd mode=0644'

echo "-- 4. ensure the app dir exists (file, as root)"
ansible -i "$INV" web -b -m file -a 'path=/etc/cap09.d state=directory mode=0755'

echo "-- 5. one fact from each node (setup + filter)"
ansible -i "$INV" web -m setup -a 'filter=ansible_distribution'
