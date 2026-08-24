#!/usr/bin/env bash
set -euo pipefail

for required in uname findmnt lsblk; do
  if ! command -v "$required" >/dev/null 2>&1; then
    echo "Required command is missing: $required" >&2
    exit 2
  fi
done

if [[ ! -r /etc/os-release ]]; then
  echo "/etc/os-release is not readable" >&2
  exit 2
fi

# shellcheck disable=SC1091  # os-release is read at run time, it is not an input to check
. /etc/os-release
: "${ID:?ID is missing from /etc/os-release}"
: "${PRETTY_NAME:?PRETTY_NAME is missing from /etc/os-release}"

echo "Distribution identity:"
printf 'ID=%s\n' "$ID"
printf 'VERSION_ID=%s\n' "${VERSION_ID:-not declared}"
printf 'ID_LIKE=%s\n' "${ID_LIKE:-not declared}"
printf 'PRETTY_NAME=%s\n' "$PRETTY_NAME"
echo "Identity check: PASS"

PACKAGE_FAMILY=unknown
PACKAGE_MANAGER=unknown
PACKAGE_QUERY=unknown

if command -v dnf >/dev/null 2>&1 && command -v rpm >/dev/null 2>&1; then
  PACKAGE_FAMILY=rpm
  PACKAGE_MANAGER=$(command -v dnf)
  PACKAGE_QUERY=$(rpm -qf /usr/bin/bash)
elif command -v apt-get >/dev/null 2>&1 && command -v dpkg-query >/dev/null 2>&1; then
  PACKAGE_FAMILY=deb
  PACKAGE_MANAGER=$(command -v apt-get)
  PACKAGE_QUERY=$(dpkg-query -S /usr/bin/bash | head -1)
elif command -v zypper >/dev/null 2>&1 && command -v rpm >/dev/null 2>&1; then
  PACKAGE_FAMILY=rpm
  PACKAGE_MANAGER=$(command -v zypper)
  PACKAGE_QUERY=$(rpm -qf /usr/bin/bash)
elif command -v pacman >/dev/null 2>&1; then
  PACKAGE_FAMILY=pacman
  PACKAGE_MANAGER=$(command -v pacman)
  PACKAGE_QUERY=$(pacman -Qo /usr/bin/bash)
elif command -v apk >/dev/null 2>&1; then
  PACKAGE_FAMILY=apk
  PACKAGE_MANAGER=$(command -v apk)
  PACKAGE_QUERY=$(apk info --who-owns /usr/bin/bash)
else
  echo "No supported native package database was found" >&2
  exit 3
fi

echo
echo "Package management:"
printf 'family=%s\nmanager=%s\nquery=%s\n' \
  "$PACKAGE_FAMILY" "$PACKAGE_MANAGER" "$PACKAGE_QUERY"
echo "Package database check: PASS"

RUNNING_KERNEL=$(uname -r)
KERNEL_DECLARATION=not-found
KERNEL_MATCH=no

case "$PACKAGE_FAMILY" in
  rpm)
    if declaration=$(rpm -q "kernel-core-$RUNNING_KERNEL" 2>/dev/null); then
      KERNEL_DECLARATION=$declaration
      KERNEL_MATCH=yes
    elif declaration=$(rpm -q "kernel-$RUNNING_KERNEL" 2>/dev/null); then
      KERNEL_DECLARATION=$declaration
      KERNEL_MATCH=yes
    fi
    ;;
  deb)
    if declaration=$(dpkg-query -W -f='${binary:Package} ${Version}\n' \
      "linux-image-$RUNNING_KERNEL" 2>/dev/null); then
      KERNEL_DECLARATION=$declaration
      KERNEL_MATCH=yes
    fi
    ;;
  pacman)
    KERNEL_DECLARATION=$(pacman -Q linux 2>/dev/null || printf 'not-found')
    ;;
  apk)
    KERNEL_DECLARATION=$(apk info -e linux-lts 2>/dev/null || printf 'not-found')
    ;;
esac

echo
echo "Kernel comparison:"
printf 'running=%s\ndeclared=%s\nexact_match=%s\n' \
  "$RUNNING_KERNEL" "$KERNEL_DECLARATION" "$KERNEL_MATCH"

ROOT_SOURCE=$(findmnt -nro SOURCE /)
ROOT_NORMALIZED=${ROOT_SOURCE%%[*}

echo
echo "Real block-backed mounts:"
findmnt --real -rn -o TARGET,SOURCE,FSTYPE | awk '$2 ~ /^\/dev\//'

echo
echo "Block-backed filesystems separate from /:"
separate_count=0
while read -r target source fstype; do
  [[ $source == /dev/* ]] || continue
  [[ $source == *'['* ]] && continue
  normalized=${source%%[*}
  if [[ $normalized != "$ROOT_NORMALIZED" ]]; then
    printf '%s %s %s\n' "$target" "$source" "$fstype"
    separate_count=$((separate_count + 1))
  fi
done < <(findmnt --real -rn -o TARGET,SOURCE,FSTYPE)

printf 'root_source=%s\nseparate_count=%s\n' "$ROOT_SOURCE" "$separate_count"
echo "Filesystem inspection check: PASS"
