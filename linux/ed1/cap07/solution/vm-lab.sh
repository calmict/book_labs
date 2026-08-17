#!/usr/bin/env bash
set -euo pipefail

BASE_IMAGE=${LABCAP07_BASE_IMAGE:?"Set LABCAP07_BASE_IMAGE to your own Rocky/RHEL-compatible qcow2 image, built per Appendix A with GRUB configured for serial output"}
WORK_DIR=$(mktemp -d /tmp/labcap07.XXXXXX)
OVERLAY=$WORK_DIR/labcap07-overlay.qcow2
CURRENT_PIDFILE=
QEMU_WAS_LEFT_RUNNING=0

cleanup() {
  status=$?
  trap - EXIT INT TERM

  if [[ -n "$CURRENT_PIDFILE" && -s "$CURRENT_PIDFILE" ]]; then
    qemu_pid=$(<"$CURRENT_PIDFILE")
    if [[ "$qemu_pid" =~ ^[0-9]+$ ]] && kill -0 "$qemu_pid" 2>/dev/null; then
      QEMU_WAS_LEFT_RUNNING=1
      kill -TERM "$qemu_pid" 2>/dev/null || true
      for _ in {1..20}; do
        kill -0 "$qemu_pid" 2>/dev/null || break
        sleep 0.1
      done
      if kill -0 "$qemu_pid" 2>/dev/null; then
        kill -KILL "$qemu_pid" 2>/dev/null || true
      fi
    fi
  fi

  rm -rf -- "$WORK_DIR"

  if (( QEMU_WAS_LEFT_RUNNING == 0 )); then
    echo "QEMU process check: PASS (no process remained alive)"
  else
    echo "QEMU process check: PASS (the EXIT trap terminated the remaining process)"
  fi
  if [[ ! -d "$WORK_DIR" ]]; then
    echo "Temporary workspace removal check: PASS ($WORK_DIR removed)"
  else
    echo "Temporary workspace removal check: FAIL" >&2
    status=1
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

for required in qemu-img timeout python3; do
  if ! command -v "$required" >/dev/null 2>&1; then
    echo "Required command is missing: $required" >&2
    exit 2
  fi
done

if command -v qemu-system-x86_64 >/dev/null 2>&1; then
  QEMU_BIN=$(command -v qemu-system-x86_64)
elif command -v qemu-kvm >/dev/null 2>&1; then
  QEMU_BIN=$(command -v qemu-kvm)
elif [[ -x /usr/libexec/qemu-kvm ]]; then
  QEMU_BIN=/usr/libexec/qemu-kvm
else
  echo "Neither qemu-system-x86_64 nor qemu-kvm is available" >&2
  exit 2
fi

if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
  echo "The current user cannot read and write /dev/kvm" >&2
  exit 2
fi
if [[ ! -r "$BASE_IMAGE" ]]; then
  echo "Base image is not readable: $BASE_IMAGE" >&2
  exit 2
fi
if ! python3 -c 'import pexpect' >/dev/null 2>&1; then
  echo "Python package pexpect is required" >&2
  exit 2
fi

BASE_IMAGE=$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$BASE_IMAGE")
if [[ $(qemu-img info --output=json "$BASE_IMAGE" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("format", ""))') != qcow2 ]]; then
  echo "The base image must use qcow2 format" >&2
  exit 2
fi

qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE" "$OVERLAY"
overlay_info=$(qemu-img info --output=json "$OVERLAY")
overlay_format=$(python3 -c 'import json, sys; print(json.load(sys.stdin).get("format", ""))' <<<"$overlay_info")
overlay_backing=$(python3 -c 'import json, sys; info=json.load(sys.stdin); print(info.get("full-backing-filename") or info.get("backing-filename", ""))' <<<"$overlay_info")
if [[ "$overlay_format" != qcow2 || -z "$overlay_backing" || ! "$BASE_IMAGE" -ef "$overlay_backing" ]]; then
  echo "Overlay backing-file verification failed" >&2
  exit 3
fi
echo "Overlay backing-file verification: PASS"
echo "Base image opened only through the qcow2 backing chain: $BASE_IMAGE"
echo "Persistent disposable overlay for all four stages: $OVERLAY"

QEMU_ARGS=(
  -enable-kvm
  -cpu host
  -smp 1
  -m 768M
  -netdev user,id=net0
  -device virtio-net-pci,netdev=net0
  -display none
  -serial mon:stdio
  -no-reboot
  -drive "file=$OVERLAY,if=virtio,format=qcow2"
)

run_stage() {
  stage=$1
  CURRENT_PIDFILE=$WORK_DIR/qemu-$stage.pid
  transcript=$WORK_DIR/$stage.serial.log
  echo
  echo "=== Stage: $stage ==="

  current_backing=$(qemu-img info --output=json "$OVERLAY" | python3 -c 'import json, sys; info=json.load(sys.stdin); print(info.get("full-backing-filename") or info.get("backing-filename", ""))')
  if [[ -z "$current_backing" || ! "$BASE_IMAGE" -ef "$current_backing" ]]; then
    echo "Overlay backing file changed before stage $stage" >&2
    exit 3
  fi

  python3 "$(dirname "$0")/vm-driver.py" \
    "$stage" "$transcript" "$CURRENT_PIDFILE" "$QEMU_BIN" "${QEMU_ARGS[@]}"

  if [[ -s "$CURRENT_PIDFILE" ]]; then
    qemu_pid=$(<"$CURRENT_PIDFILE")
    if [[ "$qemu_pid" =~ ^[0-9]+$ ]] && kill -0 "$qemu_pid" 2>/dev/null; then
      echo "QEMU remained alive after stage $stage" >&2
      exit 4
    fi
  fi
  CURRENT_PIDFILE=
  echo "Stage $stage: PASS"
}

run_stage break
run_stage broken
run_stage repair
run_stage verify

echo
echo "All destructive-boot and recovery checks: PASS"
