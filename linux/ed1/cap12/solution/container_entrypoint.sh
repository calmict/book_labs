#!/bin/sh
set -eu

CHILD_PID=""

shutdown() {
  echo "PID 1 received SIGTERM; stopping child $CHILD_PID"
  if [ -n "$CHILD_PID" ]; then
    kill -TERM "$CHILD_PID" 2>/dev/null || true
    wait "$CHILD_PID" 2>/dev/null || true
  fi
  echo "PID 1 reaped its child and is exiting"
  exit 0
}

trap shutdown TERM INT

sleep 60 &
CHILD_PID=$!
wait "$CHILD_PID"
