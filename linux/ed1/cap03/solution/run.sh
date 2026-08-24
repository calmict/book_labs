#!/usr/bin/env bash
set -euo pipefail

WORK_DIR=$(mktemp -d /tmp/labcap03.XXXXXX)

cleanup() {
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT

ensure_strace() {
  if command -v strace >/dev/null 2>&1; then
    return
  fi

  echo "strace is missing; attempting installation with dnf" >&2
  if ! command -v dnf >/dev/null 2>&1 || ! command -v sudo >/dev/null 2>&1; then
    echo "Cannot install strace automatically: sudo and dnf are required" >&2
    exit 2
  fi
  sudo dnf install -y strace
}

ensure_strace
echo "strace binary: $(command -v strace)"

PROBE_TRACE="$WORK_DIR/probe.trace"
if ! strace -qq -o "$PROBE_TRACE" /usr/bin/true 2>"$WORK_DIR/probe.error"; then
  echo "strace is installed, but this environment denies ptrace" >&2
  sed -n '1,6p' "$WORK_DIR/probe.error" >&2
  echo "No tracing claim can be made from this run" >&2
  exit 3
fi

SUMMARY="$WORK_DIR/summary.txt"
strace -qq -c -o "$SUMMARY" /usr/bin/printf 'hello\n'
grep -q 'total' "$SUMMARY"
echo "System call summary:"
cat "$SUMMARY"
echo "Summary check: PASS"

MISSING="$WORK_DIR/file-that-does-not-exist"
MISSING_TRACE="$WORK_DIR/missing.trace"
if strace -qq -e trace=openat,newfstatat,statx,access -o "$MISSING_TRACE" \
  cat "$MISSING" >"$WORK_DIR/cat.out" 2>"$WORK_DIR/cat.error"; then
  echo "Missing-file check: FAIL; cat unexpectedly succeeded" >&2
  exit 1
fi
grep -F "$MISSING" "$MISSING_TRACE" | grep -q 'ENOENT'
echo "Missing-file trace:"
grep -F "$MISSING" "$MISSING_TRACE"
echo "ENOENT check: PASS"

ROOT_TRACE="$WORK_DIR/root.trace"
ROOT_OUTPUT="$WORK_DIR/root.out"
# shellcheck disable=SC2016  # single quotes on purpose: the string is expanded by the shell that receives it
ROOT_COMMAND='printf "uid=%s\n" "$(id -u)"; cat /etc/os-release >/dev/null'

if (( EUID == 0 )); then
  strace -qq -e trace=openat,write -o "$ROOT_TRACE" sh -c "$ROOT_COMMAND" > "$ROOT_OUTPUT"
elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  # shellcheck disable=SC2024  # the redirect is the caller's on purpose: only the traced command needs root
  sudo -n strace -qq -e trace=openat,write -o "$ROOT_TRACE" \
    sh -c "$ROOT_COMMAND" > "$ROOT_OUTPUT"
elif [[ -t 0 ]] && command -v sudo >/dev/null 2>&1; then
  echo "sudo authentication is required for the UID 0 observation"
  # shellcheck disable=SC2024  # the redirect is the caller's on purpose: only the traced command needs root
  sudo strace -qq -e trace=openat,write -o "$ROOT_TRACE" \
    sh -c "$ROOT_COMMAND" > "$ROOT_OUTPUT"
else
  echo "UID 0 check cannot run without non-interactive sudo in this session" >&2
  exit 4
fi

grep -qx 'uid=0' "$ROOT_OUTPUT"
grep -Eq 'openat|write' "$ROOT_TRACE"
cat "$ROOT_OUTPUT"
echo "Root process system calls:"
grep -E 'openat|write' "$ROOT_TRACE" | head -8
echo "UID 0 still uses the system-call boundary: PASS"
