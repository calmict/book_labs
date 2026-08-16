#!/bin/sh
set -eu

PIDS=""

cleanup() {
  # TODO: terminate and wait for every PID recorded in PIDS.
  :
}
trap cleanup EXIT INT TERM

case "${1:-}" in
  cpu)
    # TODO: run four CPU-bound processes for four seconds and print their ticks.
    ;;
  nicecpu)
    # TODO: compare two CPU-bound processes with nice values 0 and 15.
    ;;
  io)
    # TODO: compare two finite dd writes with nice values 0 and 15.
    ;;
  load)
    # TODO: keep twelve runnable processes alive for eight seconds.
    ;;
  *)
    echo "usage: $0 {cpu|nicecpu|io|load}" >&2
    exit 2
    ;;
esac
