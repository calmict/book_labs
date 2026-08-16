#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK_DIR=$(mktemp -d /tmp/labcap02.XXXXXX)

cleanup() {
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT

REPORT="$WORK_DIR/report.txt"
EXPECTED="$WORK_DIR/expected.txt"
STARTED="$WORK_DIR/started.ms"
FIRST_READ="$WORK_DIR/first-read.ms"
FINISHED="$WORK_DIR/finished.ms"

awk '$9 >= 500 && $9 < 600 {print $7}' "$LAB_ROOT/start/requests-sample.txt" \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -5 > "$REPORT"

printf '      3 /api/orders\n      2 /checkout\n      2 /api/health\n' > "$EXPECTED"
diff -u "$EXPECTED" "$REPORT"

echo "HTTP 5xx report:"
cat "$REPORT"
echo "Report check: PASS"

slow_producer() {
  date +%s%3N > "$STARTED"
  printf 'first record\n'
  sleep 2
  date +%s%3N > "$FINISHED"
  printf 'second record\n'
}

slow_producer | while IFS= read -r record; do
  if [[ ! -e "$FIRST_READ" ]]; then
    date +%s%3N > "$FIRST_READ"
  fi
  printf 'consumer: %s\n' "$record"
done

start_ms=$(<"$STARTED")
first_ms=$(<"$FIRST_READ")
finish_ms=$(<"$FINISHED")
first_delay=$((first_ms - start_ms))
producer_duration=$((finish_ms - start_ms))

if (( first_ms >= finish_ms )); then
  echo "Streaming check: FAIL; first record did not arrive before producer completion" >&2
  exit 1
fi
if (( producer_duration < 1800 )); then
  echo "Timing check: FAIL; producer pause was unexpectedly short" >&2
  exit 1
fi

echo "First record received after ${first_delay} ms"
echo "Producer finished after ${producer_duration} ms"
echo "Streaming overlap check: PASS"
