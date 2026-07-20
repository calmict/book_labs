# Chapter 4 — The overlay by hand

**Level:** Intermediate

One last illusion remains to dismantle, the most convincing one: when you enter a container and type ls,
you see bin, etc, usr — it looks like another Linux installation. In chapter 2 you sensed the how (a MNT
namespace with a different root); here you mount by hand the piece that makes it *efficient*:
Copy-on-Write with OverlayFS. You will stack read-only layers, write on top, and see the magic — only one
page is copied, and only when you write it. All rootless, inside the namespaces of chapter 2.

## Objectives

- Mount an OverlayFS by hand: two read-only lowerdirs plus a writable upperdir (4.2, 4.3).
- Prove Copy-on-Write: writing a "read-only" file leaves the lower intact and copies into the upper
  (4.3).
- See that shared lowers make two containers almost free, with private uppers (4.4).
- Close the circle of chapter 2: the overlay as a root inside a MNT namespace (4.3).

## Prerequisites

- A Linux with OverlayFS in the kernel (standard) and unshare (util-linux): no Docker needed.
- No root: we mount inside a USER + MNT namespace (the namespaces of chapter 2), which on recent kernels
  allows the overlay mount without sudo.
- The MNT namespace of chapter 2 and the cgroups of chapter 3 as context: here we add storage.

## The scenario

In start/ you will find overlay.sh: a script that should mount an overlay and prove Copy-on-Write, but
mounts nothing. You fill three gaps (TODO 1..3) so the overlay exists, CoW shows, and two containers stay
isolated.

Prepare the environment:

    cd docker/ed1/cap04/start

### Phase 1 — Sharing without copying (4.1)

A hundred containers start from the same Ubuntu image. Copying it a hundred times would waste disk. You
need to share everything that does not change and copy only what is modified: that is Copy-on-Write. Here
you build it with your own hands, with no Docker.

### Phase 2 — Mounting the overlay (4.3 — TODO 1)

Open start/overlay.sh and complete **TODO 1**: mount container A — an overlay of two read-only lowers
(medio over basso) plus a writable upper —

    mount -t overlay overlay \
      -o lowerdir="$LAB/medio":"$LAB/basso",upperdir="$LAB/upperA",workdir="$LAB/workA" \
      "$LAB/mergedA"

Then record the fused view (merged_files): mergedA shows a.txt (from basso) and b.txt (from medio),
fused.

### Phase 3 — The Copy-on-Write magic (4.3 — TODO 2)

Complete **TODO 2**: write to a.txt in mergedA — but a.txt lives in the read-only lower. Record that the
lower is intact and that the change went into the upper.

    echo "modificato dal container A" > "$LAB/mergedA/a.txt"

The original file in basso/a.txt is untouched; upperA/a.txt holds the modified "photocopy".

### Phase 4 — Two containers, private uppers (4.4 — TODO 3)

Complete **TODO 3**: mount container B with the *same* lowers but a different upper (upperB/workB into
mergedB), and record what B sees for a.txt. It must see the original, not A's change: the lowers are
shared, the uppers private.

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- overlay.sh mounts container A and records the fused view (TODO 1).
- Writing to a.txt leaves the lower intact and the change in the upper (TODO 2).
- Container B, with a different upper, sees the original (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh mounts the overlay by hand and checks, point by point:

- **OK 1** — the merged view fuses the files of both lowers (a.txt and b.txt).
- **OK 2** — Copy-on-Write: the lower is untouched, the change lives in the upper.
- **OK 3** — a second container on the same lowers is isolated: it sees the original, not A's write.

## Reflection questions

**a.** Why does the lower stay intact when you write to a file that belongs to it? Describe what OverlayFS
does at the moment of writing, and why this is exactly what lets a one-gigabyte image start a hundred
containers almost without using extra disk.

**b.** Two containers on the same lowers do not see each other. Explain, with the terms lowerdir and
upperdir, why A's change never reaches B. Which isolation from chapter 2 does this correspond to, on the
storage plane?

**c.** What you write lands in the upper, which is costly and volatile. Why "costly" and why "volatile"?
And how do two disciplines from the rest of the book follow from this property — the layer cache (chapter
11) and volumes (part 4)?

## Cleanup

Nothing to tear down: the overlay is mounted inside a MNT namespace that disappears with the script,
taking the mounts with it, and the working directories live in a temporary directory the test cleans up.
No Docker container, no mount left on the host.

## Where it leads

The theory is closed, and it is no longer theory: you drove it with your hands. A container is a process
(ch1); namespaces decide what it sees (ch2); cgroups how much it consumes (ch3); Copy-on-Write how it
sees the filesystem without wasting disk (ch4). **Chapter 5** opens the tool's hood: the client-server
model and the chain dockerd, containerd, shim, runc — which automates exactly what you mounted here by
hand. For quick reference, see the volume's appendices.
