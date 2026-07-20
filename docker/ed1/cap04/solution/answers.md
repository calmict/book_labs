# Chapter 4 - The overlay by hand - answers

## The completed TODOs

TODO 1 (4.3) - mount container A and record the fused view. Two read-only lowers
(medio over basso) plus a private writable upper:

    mount -t overlay overlay \
      -o lowerdir="$LAB/medio":"$LAB/basso",upperdir="$LAB/upperA",workdir="$LAB/workA" \
      "$LAB/mergedA"
    echo "merged_files=$(cd "$LAB/mergedA" && echo *)" >> "$OUT/result.txt"

  The merged view shows a.txt (from basso) and b.txt (from medio), fused into one.

TODO 2 (4.3) - Copy-on-Write. a.txt lives in the read-only lower; writing to it
through merged copies it up and edits the copy, leaving the lower intact:

    echo "modificato dal container A" > "$LAB/mergedA/a.txt"
    echo "lower_after=$(cat "$LAB/basso/a.txt")"  >> "$OUT/result.txt"
    echo "upper_after=$(cat "$LAB/upperA/a.txt")" >> "$OUT/result.txt"

TODO 3 (4.4) - container B: the same lowers, a different upper. It sees the
original a.txt, not A's change - the lowers are shared, the uppers are private:

    mount -t overlay overlay \
      -o lowerdir="$LAB/medio":"$LAB/basso",upperdir="$LAB/upperB",workdir="$LAB/workB" \
      "$LAB/mergedB"
    echo "container_b_sees=$(cat "$LAB/mergedB/a.txt")" >> "$OUT/result.txt"

## Reflection answers

a. The lower stays intact because OverlayFS never writes to a read-only lower: on
the first write to a file that lives there, it copies the file up into the upper
and edits the copy. This is Copy-on-Write - copy only at the moment of writing,
and only the file you touch. It is exactly why a one-gigabyte image can start a
hundred containers almost for free: the lowers (the image layers) are shared and
read once; each container adds only its own small upper.

b. Two containers on the same lowers do not see each other because they share the
read-only lowers but each has its own private upper, and a write goes to the
upper. Container A's edit lives in upperA; container B reads a.txt from the shared
lower (its own upperB is empty for that file), so it sees the original. This is
the storage side of the isolation you already built with namespaces in chapter 2:
same base, private writable layer per container.

c. What lands in the upper is both costly and volatile: costly because it breaks
the sharing (it is private to that container) and volatile because it dies when
the container is removed - the upper is the writable layer of chapter 13. This is
why the disciplines of the rest of the book follow: order the Dockerfile to
maximise reuse of the shared lowers (the cache, chapter 11), and move anything
that must survive out of the upper into volumes (part 4). Copy-on-Write is not an
implementation detail; it is the constraint that shapes the right way to use
Docker.
