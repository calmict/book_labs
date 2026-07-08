#!/usr/bin/env bash
set -euo pipefail

# Chapter 5 — a tiny idempotent engine. It brings a piece of the system to a
# DESIRED STATE and reports the COLOUR of each operation:
#   ok      -> already correct, nothing done      (green)
#   changed -> a change was made                  (yellow)
#   failed  -> could not reach the desired state  (red)
# CHECK=1 turns on check mode: report what WOULD change, write nothing.
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
  if [ -f "$file" ] && grep -qxF "$line" "$file"; then
    report ok "line already present: $line"
    return 0
  fi
  if [ "$CHECK" = 1 ]; then
    report changed "WOULD add line: $line (check mode, nothing written)"
    return 0
  fi
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
# changed_when: judge by comparing the content before and after, not by exit code.
render() {
  local file="$1" desired="$2" before=""
  mkdir -p "$(dirname "$file")"
  [ -f "$file" ] && before=$(cat "$file")
  if [ "$CHECK" = 1 ]; then
    if [ "$before" = "$desired" ]; then report ok "already rendered"; else report changed "WOULD render"; fi
    return 0
  fi
  printf '%s\n' "$desired" > "$file"            # the command always runs
  if [ "$before" = "$desired" ]; then
    report ok "rendered, no change"
  else
    report changed "rendered, content changed"
  fi
}

echo "ensure the desired state in $STATE_DIR (CHECK=$CHECK):"
echo "  -- switch (ensure_line): idempotent --"
ensure_line "server=web" "$CONFIG"
ensure_line "port=8080" "$CONFIG"
echo "  -- black swan (render + changed_when) --"
render "$RENDERED" "listen 0.0.0.0:8080"
echo "  -- doorbell (append_line): never converges --"
append_line "deployed" "$LOG"
