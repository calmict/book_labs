#!/bin/sh
set -eu

CHILD_PID=""

shutdown() {
  # TODO: terminate CHILD_PID, wait for it, and exit successfully.
  :
}

trap shutdown TERM INT

sleep 60 &
CHILD_PID=$!
wait "$CHILD_PID"
