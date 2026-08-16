#!/bin/sh
set -eu

PIDS=""

remember_pid() {
  if [ -z "$PIDS" ]; then
    PIDS=$1
  else
    PIDS="$PIDS $1"
  fi
}

cleanup() {
  for pid in $PIDS; do
    kill "$pid" 2>/dev/null || true
  done
  for pid in $PIDS; do
    wait "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

ticks_for() {
  awk '{ print $14 + $15 }' "/proc/$1/stat"
}

start_busy() {
  nice_value=$1
  nice -n "$nice_value" yes >/dev/null &
  STARTED_PID=$!
  remember_pid "$STARTED_PID"
}

case "${1:-}" in
  cpu)
    index=1
    while [ "$index" -le 4 ]; do
      start_busy 0
      eval "worker_$index=$STARTED_PID"
      index=$((index + 1))
    done
    sleep 4
    index=1
    while [ "$index" -le 4 ]; do
      eval "pid=\$worker_$index"
      printf 'worker %s: pid=%s ticks=%s\n' "$index" "$pid" "$(ticks_for "$pid")"
      index=$((index + 1))
    done
    ;;
  nicecpu)
    start_busy 0
    normal_pid=$STARTED_PID
    start_busy 15
    nice_pid=$STARTED_PID
    attempt=1
    normal_wins=0
    while [ "$attempt" -le 3 ]; do
      sleep 5
      normal_ticks=$(ticks_for "$normal_pid")
      nice_ticks=$(ticks_for "$nice_pid")
      printf 'sample %s -- nice 0:  pid=%s ticks=%s\n' "$attempt" "$normal_pid" "$normal_ticks"
      printf 'sample %s -- nice 15: pid=%s ticks=%s\n' "$attempt" "$nice_pid" "$nice_ticks"
      if [ "$normal_ticks" -gt "$nice_ticks" ]; then
        normal_wins=$((normal_wins + 1))
      fi
      attempt=$((attempt + 1))
    done
    printf 'nice 0 ahead of nice 15 in %s of 3 samples\n' "$normal_wins"
    if [ "$normal_wins" -eq 0 ]; then
      echo "nice 0 was never ahead across 3 samples: on a busy shared host a single sample can tie or reverse from scheduling noise, but three consecutive misses is unexpected" >&2
      exit 1
    fi
    ;;
  io)
    echo "starting equal 64 MiB writes: nice 0 and nice 15"
    dd if=/dev/zero of=/tmp/labcap11-normal.bin bs=1M count=64 conv=fsync \
      2>/tmp/labcap11-normal.log &
    normal_pid=$!
    remember_pid "$normal_pid"
    nice -n 15 dd if=/dev/zero of=/tmp/labcap11-nice.bin bs=1M count=64 conv=fsync \
      2>/tmp/labcap11-nice.log &
    nice_pid=$!
    remember_pid "$nice_pid"
    wait "$normal_pid"
    wait "$nice_pid"
    echo "nice 0 result:"
    tail -n 2 /tmp/labcap11-normal.log
    echo "nice 15 result:"
    tail -n 2 /tmp/labcap11-nice.log
    echo "nice changes CPU scheduling priority; these I/O results have no guaranteed order"
    rm -f /tmp/labcap11-normal.bin /tmp/labcap11-nice.bin \
      /tmp/labcap11-normal.log /tmp/labcap11-nice.log
    ;;
  load)
    index=1
    while [ "$index" -le 12 ]; do
      start_busy 0
      index=$((index + 1))
    done
    echo "started 12 runnable workers under the container CPU quota"
    sleep 20
    ;;
  *)
    echo "usage: $0 {cpu|nicecpu|io|load}" >&2
    exit 2
    ;;
esac
