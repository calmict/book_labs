#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR="$SCRIPT_DIR/labcap18-work"
IMAGE="$SCRIPT_DIR/labcap18.img"
MOUNT_DIR="$SCRIPT_DIR/labcap18-mnt"
LOOP_DEVICE=""
PRIVILEGED=()

cleanup() {
  if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
    "${PRIVILEGED[@]}" umount "$MOUNT_DIR" >/dev/null 2>&1 || true
    if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
      "${PRIVILEGED[@]}" umount -l "$MOUNT_DIR" >/dev/null 2>&1 || true
    fi
  fi
  if [[ -n "$LOOP_DEVICE" ]]; then
    "${PRIVILEGED[@]}" losetup -d "$LOOP_DEVICE" >/dev/null 2>&1 || true
  fi
  rm -rf -- "$WORK_DIR"
  rm -f -- "$IMAGE"
  rmdir -- "$MOUNT_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

cleanup
mkdir -p -- "$WORK_DIR" "$MOUNT_DIR"

echo "== Hard link =="
printf 'shared content\n' > "$WORK_DIR/original.txt"
stat -c '%i %h %n' "$WORK_DIR/original.txt"
ln "$WORK_DIR/original.txt" "$WORK_DIR/hard-link.txt"
stat -c '%i %h %n' "$WORK_DIR/original.txt" "$WORK_DIR/hard-link.txt"
rm -- "$WORK_DIR/original.txt"
stat -c '%i %h %n' "$WORK_DIR/hard-link.txt"
[[ $(<"$WORK_DIR/hard-link.txt") == "shared content" ]]

echo
echo "== Broken symbolic link =="
printf 'target\n' > "$WORK_DIR/target.txt"
ln -s target.txt "$WORK_DIR/symbolic-link.txt"
rm -- "$WORK_DIR/target.txt"
if [[ -L "$WORK_DIR/symbolic-link.txt" && ! -e "$WORK_DIR/symbolic-link.txt" ]]; then
  echo "test -L: true"
  echo "test -e: false"
  echo "target: $(readlink "$WORK_DIR/symbolic-link.txt")"
else
  echo "Unexpected symbolic-link state" >&2
  exit 1
fi

echo
echo "== Atomic rename =="
printf 'version-one\n' > "$WORK_DIR/current.txt"
(
  for iteration in $(seq 1 250); do
    if (( iteration % 2 == 0 )); then
      value=version-one
    else
      value=version-two
    fi
    printf '%s\n' "$value" > "$WORK_DIR/current.tmp"
    mv -f -- "$WORK_DIR/current.tmp" "$WORK_DIR/current.txt"
  done
) &
writer_pid=$!
bad_state=0
for iteration in $(seq 1 5000); do
  value=$(<"$WORK_DIR/current.txt") || {
    bad_state=1
    break
  }
  if [[ "$value" != version-one && "$value" != version-two ]]; then
    bad_state=1
    break
  fi
done
wait "$writer_pid"
if (( bad_state != 0 )); then
  echo "Reader observed a missing or partial state" >&2
  exit 1
fi
echo "5000 reads: only version-one or version-two"

echo
echo "== Inode exhaustion on an image filesystem =="
dd if=/dev/zero of="$IMAGE" bs=1M count=16 status=none
mkfs.ext4 -q -F -N 128 "$IMAGE"

if (( EUID == 0 )); then
  PRIVILEGED=()
elif sudo -n true >/dev/null 2>&1; then
  PRIVILEGED=(sudo -n)
else
  echo "SKIPPED: losetup and mount require root or passwordless sudo."
  echo "The image was created and formatted, but it was never mounted."
  exit 0
fi

LOOP_DEVICE=$("${PRIVILEGED[@]}" losetup --find --show "$IMAGE")
"${PRIVILEGED[@]}" mount "$LOOP_DEVICE" "$MOUNT_DIR"
created=0
while "${PRIVILEGED[@]}" touch "$MOUNT_DIR/file-$created" 2>/dev/null; do
  ((created += 1)) || true
done
echo "empty files created: $created"
df -h "$MOUNT_DIR"
df -i "$MOUNT_DIR"
if (( $(df --output=iavail "$MOUNT_DIR" | tail -1) != 0 )); then
  echo "Expected zero free inodes" >&2
  exit 1
fi
echo "inode exhaustion confirmed with cleanup pending"
