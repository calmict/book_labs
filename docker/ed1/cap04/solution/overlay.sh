#!/usr/bin/env bash
# cap04 solution - "the overlay by hand": stack two read-only layers plus a
# writable one with OverlayFS and prove Copy-on-Write - a write to a file that
# lives in a read-only lower lands in the upper, leaving the lower intact - and
# that two containers (two uppers on the same lowers) do not see each other.
# Rootless: the overlay is mounted inside a USER + MNT namespace, so no sudo and
# no Docker (the same namespaces of chapter 2).
set -euo pipefail

OUT="${1:?usage: overlay.sh OUTPUT_DIR}"
mkdir -p "$OUT"

LAB=$(mktemp -d)
mkdir -p "$LAB"/{basso,medio,upperA,workA,mergedA,upperB,workB,mergedB}
echo "vengo dal layer basso" > "$LAB/basso/a.txt"
echo "vengo dal layer medio" > "$LAB/medio/b.txt"

# All the overlay work happens inside a USER + MNT namespace (chapter 2), which
# is what lets it mount without sudo. The body is single-quoted on purpose.
# shellcheck disable=SC2016
unshare --user --map-root-user --mount bash -c '
  LAB="'"$LAB"'"; OUT="'"$OUT"'"
  # Container A: an overlay of two read-only lowers (medio over basso) plus a
  # private writable upper.
  mount -t overlay overlay \
    -o lowerdir="$LAB/medio":"$LAB/basso",upperdir="$LAB/upperA",workdir="$LAB/workA" \
    "$LAB/mergedA"
  # The merged view shows files from BOTH lowers, fused.
  echo "merged_files=$(cd "$LAB/mergedA" && echo *)" > "$OUT/result.txt"
  # Copy-on-Write: write to a.txt, which lives in the read-only lower.
  echo "modificato dal container A" > "$LAB/mergedA/a.txt"
  echo "lower_after=$(cat "$LAB/basso/a.txt")"  >> "$OUT/result.txt"
  echo "upper_after=$(cat "$LAB/upperA/a.txt")" >> "$OUT/result.txt"
  # Container B: the SAME lowers, a DIFFERENT upper. It must not see A s change.
  mount -t overlay overlay \
    -o lowerdir="$LAB/medio":"$LAB/basso",upperdir="$LAB/upperB",workdir="$LAB/workB" \
    "$LAB/mergedB"
  echo "container_b_sees=$(cat "$LAB/mergedB/a.txt")" >> "$OUT/result.txt"
'
rm -rf "$LAB"
