#!/usr/bin/env bash
set -euo pipefail

KERNEL_RELEASE=$(uname -r)
SOURCE_IMAGE=${1:-/boot/initramfs-$KERNEL_RELEASE.img}
INSPECT_IMAGE=/tmp/labcap07-inspect.img
LISTING=$(mktemp /tmp/labcap07-listing.XXXXXX)
COPY_CREATED=0

cleanup() {
  status=$?
  trap - EXIT INT TERM
  rm -f -- "$LISTING"
  if (( COPY_CREATED == 1 )) && [[ -f "$INSPECT_IMAGE" && ! -L "$INSPECT_IMAGE" ]]; then
    rm -f -- "$INSPECT_IMAGE"
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

if ! command -v lsinitrd >/dev/null 2>&1; then
  echo "Required command is missing: lsinitrd" >&2
  echo "Install the dracut package with this host's package manager." >&2
  exit 2
fi
if [[ ! -r "$SOURCE_IMAGE" ]]; then
  echo "Initramfs is not readable by the current user: $SOURCE_IMAGE" >&2
  echo "Grant read access or run this read-only inspection in an authorized administrative shell." >&2
  exit 2
fi
if [[ -e "$INSPECT_IMAGE" || -L "$INSPECT_IMAGE" ]]; then
  echo "Refusing to replace an existing path: $INSPECT_IMAGE" >&2
  echo "Remove that path after checking who owns it, then run the inspection again." >&2
  exit 2
fi

cp -- "$SOURCE_IMAGE" "$INSPECT_IMAGE"
COPY_CREATED=1
echo "Kernel release: $KERNEL_RELEASE"
echo "Source image: $SOURCE_IMAGE"
echo "Read-only inspection copy: $INSPECT_IMAGE"
ls -lh -- "$INSPECT_IMAGE"

lsinitrd "$INSPECT_IMAGE" | tee "$LISTING"

echo
echo "=== Lines containing module ==="
grep -i module "$LISTING" || true

echo
echo "=== Dracut functional modules ==="
lsinitrd -m "$INSPECT_IMAGE"

echo
echo "=== Kernel module files in the archive ==="
grep -E '\.ko(\.(xz|gz|zst))?$' "$LISTING" || true

echo
echo "=== Root-mount and handoff candidates ==="
mapfile -t CANDIDATES < <(
  awk '$1 ~ /^-/ && $NF ~ /^(usr\/lib\/dracut\/hooks\/|usr\/lib\/systemd\/system\/)/ {print $NF}' "$LISTING" \
    | grep -E '(root|mount|devexists|pivot|switch)' \
    | sort -u
)
if (( ${#CANDIDATES[@]} == 0 )); then
  echo "No filename matched the automatic filter; inspect the full hook list below."
else
  printf '%s\n' "${CANDIDATES[@]}"
fi

echo
echo "=== All dracut hook files ==="
awk '$1 ~ /^-/ && $NF ~ /^usr\/lib\/dracut\/hooks\// {print $NF}' "$LISTING" | sort -u

echo
echo "=== Contents of textual root-mount and handoff candidates ==="
shown=0
for candidate in "${CANDIDATES[@]}"; do
  case "$candidate" in
    *.sh|*.service|*.target)
      echo
      echo "--- $candidate ---"
      lsinitrd -f "$candidate" "$INSPECT_IMAGE"
      shown=$((shown + 1))
      ;;
  esac
done
if (( shown == 0 )); then
  echo "No textual candidate was selected automatically."
fi

echo
echo "Inspection complete; the EXIT trap removes only the copy under /tmp."
