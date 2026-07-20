#!/usr/bin/env bash
# cap04 start - build an OverlayFS by hand and prove Copy-on-Write. Rootless: the
# overlay is mounted inside a USER + MNT namespace (chapter 2), so no sudo and no
# Docker. Three gaps to fill (TODO 1..3). As written nothing is mounted.
set -euo pipefail

OUT="${1:?usage: overlay.sh OUTPUT_DIR}"
mkdir -p "$OUT"

LAB=$(mktemp -d)
mkdir -p "$LAB"/{basso,medio,upperA,workA,mergedA,upperB,workB,mergedB}
echo "vengo dal layer basso" > "$LAB/basso/a.txt"
echo "vengo dal layer medio" > "$LAB/medio/b.txt"

# shellcheck disable=SC2016
unshare --user --map-root-user --mount bash -c '
  LAB="'"$LAB"'"; OUT="'"$OUT"'"
  : > "$OUT/result.txt"

  # TODO 1 (4.3): mount container A - an overlay of two read-only lowers
  #   (medio over basso) plus a private writable upper. Fill in:
  #     mount -t overlay overlay \
  #       -o lowerdir="$LAB/medio":"$LAB/basso",upperdir="$LAB/upperA",workdir="$LAB/workA" \
  #       "$LAB/mergedA"
  # Then record the fused view:
  #     echo "merged_files=$(cd "$LAB/mergedA" && echo *)" >> "$OUT/result.txt"

  # TODO 2 (4.3): Copy-on-Write. Write to a.txt in mergedA (a.txt lives in the
  #   read-only lower), then record that the lower is intact and the change went
  #   to the upper:
  #     echo "modificato dal container A" > "$LAB/mergedA/a.txt"
  #     echo "lower_after=$(cat "$LAB/basso/a.txt")"  >> "$OUT/result.txt"
  #     echo "upper_after=$(cat "$LAB/upperA/a.txt")" >> "$OUT/result.txt"

  # TODO 3 (4.4): container B - the SAME lowers, a DIFFERENT upper (upperB/workB
  #   into mergedB). Mount it, then record what B sees for a.txt: it must be the
  #   original, not A s change.
  #     echo "container_b_sees=$(cat "$LAB/mergedB/a.txt")" >> "$OUT/result.txt"
  true
'
rm -rf "$LAB"
