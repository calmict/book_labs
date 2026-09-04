#!/usr/bin/env bash
# Chapter 4 solution - inspect an OCI image and demonstrate copy-on-write,
# reduced capabilities, and the shared kernel. Rootless and throwaway.
set -euo pipefail

OUT=${1:?usage: image-lab.sh OUTPUT_DIR}
IMAGE=${CAP04_IMAGE:-alpine:3}
mkdir -p "$OUT/image" "$OUT/layer"

docker pull -q "$IMAGE" >/dev/null
docker save "$IMAGE" -o "$OUT/image.tar"
tar -xf "$OUT/image.tar" -C "$OUT/image"

config_path=$(jq -r '.[0].Config' "$OUT/image/manifest.json")
layer_path=$(jq -r '.[0].Layers[0]' "$OUT/image/manifest.json")
printf 'config_path=%s\nlayer_path=%s\n' "$config_path" "$layer_path" > "$OUT/image.env"
tar -xf "$OUT/image/$layer_path" -C "$OUT/layer"

cat > "$OUT/overlay-inner.sh" <<'INNER'
#!/usr/bin/env sh
set -eu
cd "$1"
mkdir upper work merged
if [ "${CAP04_READ_ONLY:-0}" = 1 ]; then
  mount -t overlay overlay -o "lowerdir=layer" merged
else
  mount -t overlay overlay -o "lowerdir=layer,upperdir=upper,workdir=work" merged
fi
inner_cleanup() {
  umount merged 2>/dev/null || true
  chmod -R u+rwX upper work merged 2>/dev/null || true
  rm -rf upper work merged
}
trap inner_cleanup EXIT
lower_before=$(sha256sum layer/etc/motd | awk '{print $1}')
printf '%s\n' 'modified from the container' > merged/etc/motd
rm merged/etc/hostname
lower_after=$(sha256sum layer/etc/motd | awk '{print $1}')
test -f layer/etc/hostname
test ! -e merged/etc/hostname
test -f upper/etc/motd
printf 'lower_before=%s\nlower_after=%s\nmerged_hostname_absent=yes\nupper_motd_present=yes\n' \
  "$lower_before" "$lower_after" > overlay.env
INNER
chmod +x "$OUT/overlay-inner.sh"
unshare -Urm "$OUT/overlay-inner.sh" "$OUT"

container_cap=$(docker run --rm "$IMAGE" awk '/^CapEff:/ {print $2}' /proc/self/status)
host_cap=$(awk '/^CapEff:/ {print $2}' /proc/1/status)
clock_output=$(docker run --rm "$IMAGE" date -s '2000-01-01' 2>&1 || true)
host_kernel=$(uname -r)
container_kernel=$(docker run --rm "$IMAGE" uname -r)
{
  printf 'container_cap=%s\nhost_cap=%s\n' "$container_cap" "$host_cap"
  printf 'clock_refused=%s\n' "$(printf '%s' "$clock_output" | grep -Eic 'not permitted|permission denied')"
  printf 'host_kernel=%s\ncontainer_kernel=%s\n' "$host_kernel" "$container_kernel"
} > "$OUT/isolation.env"
