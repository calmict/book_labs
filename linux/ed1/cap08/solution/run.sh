#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
UNIT_DIR=$HOME/.config/systemd/user
RUNTIME_ROOT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
LAB_RUNTIME=$RUNTIME_ROOT/labcap08
READY_UNIT=labcap08-ready.service
MAIN_UNIT=labcap08-timestamp.service
ENABLE_LINK=$UNIT_DIR/default.target.wants/$MAIN_UNIT
INSTALLED=0
RUNTIME_OWNED=0

cleanup() {
  status=$?
  trap - EXIT INT TERM

  if (( INSTALLED == 1 )); then
    systemctl --user disable --now "$MAIN_UNIT" >/dev/null 2>&1 || true
    systemctl --user stop "$READY_UNIT" >/dev/null 2>&1 || true
    rm -f -- "$ENABLE_LINK" "$UNIT_DIR/$MAIN_UNIT" "$UNIT_DIR/$READY_UNIT"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user reset-failed "$MAIN_UNIT" "$READY_UNIT" >/dev/null 2>&1 || true
  fi
  if (( RUNTIME_OWNED == 1 )); then
    rm -rf -- "$LAB_RUNTIME"
  fi

  cleanup_ok=1
  if [[ -e "$UNIT_DIR/$MAIN_UNIT" || -e "$UNIT_DIR/$READY_UNIT" || -L "$ENABLE_LINK" ]]; then
    cleanup_ok=0
  fi
  if (( RUNTIME_OWNED == 1 )) && [[ -e "$LAB_RUNTIME" ]]; then
    cleanup_ok=0
  fi
  if (( cleanup_ok == 1 )); then
    echo "Cleanup check: PASS (units and runtime data removed)"
  else
    echo "Cleanup check: FAIL" >&2
    status=1
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

for command_name in systemctl systemd-analyze install awk sed; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is missing: $command_name" >&2
    exit 2
  fi
done

if ! systemctl --user show-environment >/dev/null; then
  echo "The systemd user manager is not reachable from this session" >&2
  exit 2
fi

if [[ -e "$UNIT_DIR/$MAIN_UNIT" || -e "$UNIT_DIR/$READY_UNIT" || -L "$ENABLE_LINK" || -e "$LAB_RUNTIME" ]]; then
  echo "Existing labcap08 files found; refusing to overwrite them" >&2
  exit 2
fi

mkdir -p -- "$UNIT_DIR"
INSTALLED=1
install -m 0644 "$SCRIPT_DIR/$READY_UNIT" "$UNIT_DIR/$READY_UNIT"
install -m 0644 "$SCRIPT_DIR/$MAIN_UNIT" "$UNIT_DIR/$MAIN_UNIT"
systemctl --user daemon-reload
systemctl --user reset-failed "$MAIN_UNIT" "$READY_UNIT" >/dev/null 2>&1 || true
RUNTIME_OWNED=1

echo "== start changes runtime state, not enablement =="
systemctl --user start "$MAIN_UNIT"
for attempt in {1..80}; do
  timestamp_count=$(awk 'END { print NR + 0 }' "$LAB_RUNTIME/timestamps.log" 2>/dev/null || true)
  active_state=$(systemctl --user is-active "$MAIN_UNIT" 2>/dev/null || true)
  if [[ "$timestamp_count" -ge 2 && "$active_state" == active ]]; then
    break
  fi
  sleep 0.1
done
timestamp_count=$(awk 'END { print NR + 0 }' "$LAB_RUNTIME/timestamps.log")
active_state=$(systemctl --user is-active "$MAIN_UNIT")
enabled_state=$(systemctl --user is-enabled "$MAIN_UNIT" 2>/dev/null || true)
restart_count=$(systemctl --user show "$MAIN_UNIT" --property=NRestarts --value)
printf 'is-active: %s\n' "$active_state"
printf 'is-enabled: %s\n' "$enabled_state"
printf 'timestamps: %s\n' "$timestamp_count"
printf 'NRestarts: %s\n' "$restart_count"
sed -n '1,4p' "$LAB_RUNTIME/timestamps.log"
[[ "$active_state" == active ]]
[[ "$enabled_state" == disabled ]]
[[ "$timestamp_count" -ge 2 ]]
[[ "$restart_count" -ge 1 ]]
[[ -s "$LAB_RUNTIME/ready-at" ]]

echo
echo "== enable changes future-start configuration, not runtime state =="
systemctl --user stop "$MAIN_UNIT" "$READY_UNIT"
systemctl --user enable "$MAIN_UNIT"
enabled_state=$(systemctl --user is-enabled "$MAIN_UNIT")
active_state=$(systemctl --user is-active "$MAIN_UNIT" 2>/dev/null || true)
printf 'is-enabled after enable: %s\n' "$enabled_state"
printf 'is-active before explicit start: %s\n' "$active_state"
[[ "$enabled_state" == enabled ]]
[[ "$active_state" == inactive ]]
systemctl --user start "$MAIN_UNIT"
[[ $(systemctl --user is-active "$MAIN_UNIT") == active ]]
echo "is-active after explicit start: active"

echo
echo "== host boot analysis, read only =="
echo "First five blame entries:"
systemd-analyze blame --no-pager | sed -n '1,5p'
echo "Critical chain:"
systemd-analyze critical-chain --no-pager | sed -n '1,24p'

echo
echo "All user-service checks passed."
