#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR="$SCRIPT_DIR/labcap21-work"
IMAGE=${LABCAP21_IMAGE:-rockylinux:9}
CONTAINER=labcap21-capability

cleanup() {
  chmod -R u+rwx -- "$WORK_DIR" >/dev/null 2>&1 || true
  rm -rf -- "$WORK_DIR"
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

cleanup
mkdir -p -- "$WORK_DIR/delete" "$WORK_DIR/traverse" "$WORK_DIR/scratch"

echo "== Delete an unreadable file =="
printf 'unreadable content\n' > "$WORK_DIR/delete/unreadable.txt"
chmod 000 "$WORK_DIR/delete/unreadable.txt"
if cat "$WORK_DIR/delete/unreadable.txt" >/dev/null 2>&1; then
  echo "Unexpected read success" >&2
  exit 1
fi
rm -- "$WORK_DIR/delete/unreadable.txt"
echo "mode 000 file: unreadable, deletion succeeded with directory write and search"

printf 'content\n' > "$WORK_DIR/delete/unreadable.txt"
chmod 000 "$WORK_DIR/delete/unreadable.txt"
chmod 500 "$WORK_DIR/delete"
if rm -- "$WORK_DIR/delete/unreadable.txt" >/dev/null 2>&1; then
  echo "Unexpected deletion without directory write permission" >&2
  exit 1
fi
echo "directory mode 0500: deletion denied without write"
chmod 600 "$WORK_DIR/delete"
if rm -- "$WORK_DIR/delete/unreadable.txt" >/dev/null 2>&1; then
  echo "Unexpected deletion without directory search permission" >&2
  exit 1
fi
echo "directory mode 0600: deletion denied without search"
chmod 700 "$WORK_DIR/delete"

echo
echo "== Search without listing =="
printf 'known content\n' > "$WORK_DIR/traverse/known.txt"
chmod 0644 "$WORK_DIR/traverse/known.txt"
chmod 0111 "$WORK_DIR/traverse"
known_content=$(<"$WORK_DIR/traverse/known.txt")
if [[ "$known_content" != "known content" ]]; then
  echo "Known-name lookup failed" >&2
  exit 1
fi
if ls "$WORK_DIR/traverse" >/dev/null 2>&1; then
  echo "Unexpected directory listing success" >&2
  exit 1
fi
echo "known path read: $known_content"
echo "directory listing: permission denied as expected"
chmod 0700 "$WORK_DIR/traverse"

echo
echo "== Build the harmless raw-socket probe =="
cc -O2 -Wall -Wextra -Werror "$SCRIPT_DIR/raw_socket_probe.c" -o "$WORK_DIR/raw-socket-probe"
echo "probe compiled as a regular, non-setuid file"

echo
echo "== Container runtime preflight =="
if ! docker info >/dev/null 2>&1; then
  echo "SKIPPED: Docker is installed but its daemon is not accessible."
  echo "No setuid bit, file capability, or user was created on the host."
  exit 0
fi

docker run --rm --name "$CONTAINER" \
  --volume "$WORK_DIR:/labcap21-exercise:ro,Z" \
  --tmpfs "/labcap21-exercise/scratch:rw,exec,suid,size=10m,mode=0755" \
  "$IMAGE" bash -ceu '
    cp /labcap21-exercise/raw-socket-probe /labcap21-exercise/scratch/raw-socket-probe
    chown root:root /labcap21-exercise/scratch/raw-socket-probe
    chmod 0755 /labcap21-exercise/scratch/raw-socket-probe
    useradd --uid 25001 --no-create-home labcap21user

    if runuser -u labcap21user -- /labcap21-exercise/scratch/raw-socket-probe; then
      echo "Unexpected raw-socket success without privileges" >&2
      exit 1
    fi
    echo "unprivileged copy: raw socket denied as expected"

    chmod 4755 /labcap21-exercise/scratch/raw-socket-probe
    echo "setuid copy"
    runuser -u labcap21user -- /labcap21-exercise/scratch/raw-socket-probe

    chmod u-s /labcap21-exercise/scratch/raw-socket-probe
    setcap cap_net_raw=ep /labcap21-exercise/scratch/raw-socket-probe
    echo "capability copy"
    getcap /labcap21-exercise/scratch/raw-socket-probe
    runuser -u labcap21user -- /labcap21-exercise/scratch/raw-socket-probe
  '
echo "setuid-to-capability replacement: passed"
