#!/usr/bin/env bash
set -euo pipefail

# Chapter 5 — a tiny idempotent engine (starting point). It should bring a piece
# of the system to a DESIRED STATE and report the COLOUR of each operation:
#   ok      -> already correct, nothing done      (green)
#   changed -> a change was made                  (yellow)
#   failed  -> could not reach the desired state  (red)
#
# As delivered it is NOT idempotent yet: run it twice and ensure_line still says
# [changed]. Complete the three TODOs to turn it into a real switch.
#
# Usage: ensure.sh [STATE_DIR]   (default: ./state)

CHECK="${CHECK:-0}"
STATE_DIR="${1:-./state}"
CONFIG="$STATE_DIR/app.conf"
RENDERED="$STATE_DIR/rendered.conf"
LOG="$STATE_DIR/notes.log"

report() { printf '  [%-7s] %s\n' "$1" "$2"; }

# A SWITCH: ensure a line is present. Flip to ON; already ON -> nothing.
ensure_line() {
  local line="$1" file="$2"
  mkdir -p "$(dirname "$file")"
  # TODO 1 (the switch): if the line is already present, report ok and return.
  # Otherwise add it and report changed. Use: grep -qxF "$line" "$file"
  #
  # TODO 2 (check mode): when CHECK=1, report that it WOULD add the line, but do
  # NOT write anything.
  #
  # Naive placeholder (delete once TODO 1/2 are done): always appends.
  echo "$line" >> "$file"
  report changed "added line: $line"
}

# A DOORBELL: always appends. Never converges; every run rings again.
append_line() {
  local line="$1" file="$2"
  mkdir -p "$(dirname "$file")"
  if [ "$CHECK" = 1 ]; then
    report changed "WOULD append: $line (check mode)"
    return 0
  fi
  echo "$line" >> "$file"
  report changed "appended (again): $line"
}

# A BLACK SWAN: the write ALWAYS runs, so exit 0 says nothing about change.
render() {
  local file="$1" desired="$2"
  mkdir -p "$(dirname "$file")"
  if [ "$CHECK" = 1 ]; then
    report changed "WOULD render"
    return 0
  fi
  # TODO 3 (changed_when): the write below always runs, so you cannot trust "it
  # ran" as "it changed". Capture the file's content BEFORE the write into a
  # local (e.g. before=""; [ -f "$file" ] && before=$(cat "$file")), then after
  # the write compare "$before" with "$desired": if they match report ok, else
  # changed. Right now it is always yellow.
  printf '%s\n' "$desired" > "$file"            # the command always runs
  report changed "rendered (always yellow until you add changed_when)"
}

echo "ensure the desired state in $STATE_DIR (CHECK=$CHECK):"
echo "  -- switch (ensure_line): idempotent --"
ensure_line "server=web" "$CONFIG"
ensure_line "port=8080" "$CONFIG"
echo "  -- black swan (render + changed_when) --"
render "$RENDERED" "listen 0.0.0.0:8080"
echo "  -- doorbell (append_line): never converges --"
append_line "deployed" "$LOG"
