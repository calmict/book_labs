#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR="$SCRIPT_DIR/labcap20-work"
IMAGE=${LABCAP20_IMAGE:-rockylinux:9}
CONTAINERS=(labcap20-identity labcap20-world-a labcap20-world-b)

cleanup() {
  for container in "${CONTAINERS[@]}"; do
    docker rm -f "$container" >/dev/null 2>&1 || true
  done
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT INT TERM

echo "== PAM chain on the host, read only =="
pam_files=(/etc/pam.d/login)
while IFS= read -r included; do
  if [[ -f "/etc/pam.d/$included" ]]; then
    pam_files+=("/etc/pam.d/$included")
  fi
done < <(awk '$2 == "include" || $2 == "substack" {print $3}' /etc/pam.d/login | sort -u)
for pam_file in "${pam_files[@]}"; do
  echo "-- $pam_file"
  awk '$1 ~ /^-?(auth|account|password|session)$/ {print}' "$pam_file"
done
mapfile -t pam_groups < <(
  awk '$1 ~ /^-?(auth|account|password|session)$/ {gsub(/^-/, "", $1); print $1}' "${pam_files[@]}" | sort -u
)
echo "functional groups: ${pam_groups[*]}"
if [[ " ${pam_groups[*]} " != *" auth "* ||
      " ${pam_groups[*]} " != *" account "* ||
      " ${pam_groups[*]} " != *" password "* ||
      " ${pam_groups[*]} " != *" session "* ]]; then
  echo "The selected PAM chain does not expose all four functional groups" >&2
  exit 1
fi

echo
echo "== Container runtime preflight =="
if ! docker info >/dev/null 2>&1; then
  echo "SKIPPED: Docker is installed but its daemon is not accessible."
  echo "No users, UIDs, or shared-volume files were created on the host."
  exit 0
fi

cleanup
mkdir -p -- "$WORK_DIR/identity" "$WORK_DIR/shared"
chmod 0777 "$WORK_DIR/identity" "$WORK_DIR/shared"

echo "== UID renumbering and name resolution =="
docker run --rm --name labcap20-identity \
  --volume "$WORK_DIR/identity:/lab:Z" \
  "$IMAGE" bash -ceu '
    useradd --uid 21001 --no-create-home labcap20alice
    touch /lab/owned
    chown 21001:21001 /lab/owned
    echo "before usermod"
    stat -c "uid=%u owner=%U" /lab/owned
    usermod --uid 21002 labcap20alice
    echo "after usermod"
    stat -c "uid=%u owner=%U" /lab/owned
    useradd --uid 21001 --no-create-home labcap20replacement
    echo "after reusing UID 21001"
    stat -c "uid=%u owner=%U" /lab/owned
  '

echo
echo "== Shared volume, world A: name maps to UID 23001 =="
docker run --rm --name labcap20-world-a \
  --volume "$WORK_DIR/shared:/shared:Z" \
  "$IMAGE" bash -ceu '
    useradd --uid 23001 --no-create-home labcap20shared
    runuser -u labcap20shared -- sh -c "umask 077; printf world-a > /shared/data.txt"
    stat -c "uid=%u owner=%U mode=%a" /shared/data.txt
  '

echo
echo "== Shared volume, world B: same name maps to UID 24001 =="
docker run --rm --name labcap20-world-b \
  --volume "$WORK_DIR/shared:/shared:Z" \
  "$IMAGE" bash -ceu '
    useradd --uid 24001 --no-create-home labcap20shared
    stat -c "uid=%u owner=%U mode=%a" /shared/data.txt
    if runuser -u labcap20shared -- cat /shared/data.txt >/dev/null 2>&1; then
      echo "Unexpected read success" >&2
      exit 1
    fi
    echo "read as UID 24001: permission denied as expected"
  '

echo "container identity and UID mismatch tests: passed"
