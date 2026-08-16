#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR=${1:-$HOME}
WORK_DIR=$(mktemp -d /tmp/labcap05.XXXXXX)
PARTIAL_BACKUP=

if command -v git >/dev/null 2>&1 && \
   git -C "$OUTPUT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Refusing to write the backup into a git working tree: $OUTPUT_DIR" >&2
  echo "This archive holds your real boot configuration. Pass a plain directory," >&2
  echo "for example: solution/run.sh \$HOME/boot-backups" >&2
  exit 1
fi

cleanup() {
  status=$?
  if (( status != 0 )) && [[ -n "$PARTIAL_BACKUP" && -e "$PARTIAL_BACKUP" ]]; then
    rm -f -- "$PARTIAL_BACKUP"
  fi
  rm -rf -- "$WORK_DIR"
  exit "$status"
}
trap cleanup EXIT

for required in findmnt find sort tar sha256sum gzip; do
  if ! command -v "$required" >/dev/null 2>&1; then
    echo "Required command is missing: $required" >&2
    exit 2
  fi
done

install_efibootmgr() {
  if command -v efibootmgr >/dev/null 2>&1; then
    return
  fi

  echo "efibootmgr is missing; attempting package installation" >&2
  if (( EUID == 0 )); then
    if command -v dnf >/dev/null 2>&1; then
      dnf install -y efibootmgr
    elif command -v apt-get >/dev/null 2>&1; then
      apt-get update
      apt-get install -y efibootmgr
    else
      echo "No supported package manager can install efibootmgr" >&2
      exit 2
    fi
  elif command -v sudo >/dev/null 2>&1; then
    if command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y efibootmgr
    elif command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y efibootmgr
    else
      echo "No supported package manager can install efibootmgr" >&2
      exit 2
    fi
  else
    echo "efibootmgr is missing and sudo is unavailable" >&2
    exit 2
  fi
}

if [[ ! -d /sys/firmware/efi ]]; then
  echo "Firmware mode: BIOS"
  echo "The UEFI interface is absent; ESP and NVRAM steps do not apply to this boot"
  echo "No UEFI backup was created"
  exit 5
fi

echo "Firmware mode: UEFI"
printf 'UEFI\n' > "$WORK_DIR/firmware-mode.txt"
echo "UEFI interface:"
ls /sys/firmware/efi

install_efibootmgr
EFIBOOT_OUTPUT="$WORK_DIR/efibootmgr-v.txt"
if ! efibootmgr -v > "$EFIBOOT_OUTPUT" 2>"$WORK_DIR/efibootmgr.error"; then
  echo "efibootmgr could not read the firmware variables" >&2
  sed -n '1,8p' "$WORK_DIR/efibootmgr.error" >&2
  exit 3
fi

grep -E '^(BootCurrent|BootOrder|Boot[0-9A-Fa-f]{4})' "$EFIBOOT_OUTPUT"
grep -q '^BootCurrent:' "$EFIBOOT_OUTPUT"
grep -q '^BootOrder:' "$EFIBOOT_OUTPUT"
grep -Eq '^Boot[0-9A-Fa-f]{4}' "$EFIBOOT_OUTPUT"
echo "NVRAM read-only check: PASS"

ESP_MOUNT=$(findmnt -nro TARGET /boot/efi 2>/dev/null || true)
if [[ -z "$ESP_MOUNT" ]]; then
  ESP_MOUNT=$(findmnt -rn -t vfat,fat,msdos -o TARGET | head -1)
fi
if [[ -z "$ESP_MOUNT" ]]; then
  echo "No mounted EFI System Partition was found" >&2
  exit 3
fi

findmnt -nro TARGET,SOURCE,FSTYPE,OPTIONS "$ESP_MOUNT" \
  > "$WORK_DIR/esp-mount.txt"
echo "ESP mount:"
cat "$WORK_DIR/esp-mount.txt"

READ_PREFIX=()
if [[ -r "$ESP_MOUNT" && -x "$ESP_MOUNT" ]]; then
  READ_PREFIX=()
elif (( EUID == 0 )); then
  READ_PREFIX=()
elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  READ_PREFIX=(sudo -n)
elif [[ -t 0 ]] && command -v sudo >/dev/null 2>&1; then
  echo "sudo authentication is required for read-only ESP access"
  sudo true
  READ_PREFIX=(sudo)
else
  echo "The ESP is mounted but this session cannot read it" >&2
  echo "Run the solution from an interactive terminal with sudo available" >&2
  exit 4
fi

"${READ_PREFIX[@]}" find "$ESP_MOUNT" -maxdepth 5 -printf '%y %P\n' \
  | sort > "$WORK_DIR/esp-files.txt"
echo "ESP files:"
sed -n '1,80p' "$WORK_DIR/esp-files.txt"

"${READ_PREFIX[@]}" tar -C "$ESP_MOUNT" -cf - . > "$WORK_DIR/esp.tar"
tar -tf "$WORK_DIR/esp.tar" >/dev/null
echo "ESP copy check: PASS"

(
  cd "$WORK_DIR"
  sha256sum \
    firmware-mode.txt \
    efibootmgr-v.txt \
    esp-mount.txt \
    esp-files.txt \
    esp.tar \
    > SHA256SUMS
  sha256sum -c SHA256SUMS
)

mkdir -p -- "$OUTPUT_DIR"
timestamp=$(date -u +%Y%m%dT%H%M%S.%NZ)
FINAL_BACKUP="$OUTPUT_DIR/labcap05-boot-backup-$timestamp.tar.gz"
PARTIAL_BACKUP=$(mktemp "$OUTPUT_DIR/.labcap05-backup.XXXXXX")

tar -C "$WORK_DIR" -czf "$PARTIAL_BACKUP" \
  firmware-mode.txt efibootmgr-v.txt esp-mount.txt esp-files.txt esp.tar SHA256SUMS
gzip -t "$PARTIAL_BACKUP"
tar -tzf "$PARTIAL_BACKUP" >/dev/null
mv -- "$PARTIAL_BACKUP" "$FINAL_BACKUP"
PARTIAL_BACKUP=

echo "Backup archive: $FINAL_BACKUP"
echo "Archive verification: PASS"
echo "Copy this archive to independent storage"
