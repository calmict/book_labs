# Chapter 8 — Answers

## The completed TODOs

**TODO 1 (8.2) — count the layers of the image and of the base:**

    layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$TAG")
    base_layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$BASE")

**TODO 2 (8.3) — the image ID (config digest) and the top layer digest:**

    image_id=$(docker image inspect -f '{{.Id}}' "$TAG")
    top_layer=$(docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG" | grep '^sha256' | tail -1)

**TODO 3 (8.4) — build the child and count the shared layers:**

    docker build -q -t "$TAG-child" - >/dev/null <<CHILD
    FROM $TAG
    RUN echo three > /three.txt
    CHILD
    child_layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$TAG-child")
    docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG" | grep '^sha256' | sort > "$OUT/.p"
    docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG-child" | grep '^sha256' | sort > "$OUT/.c"
    shared=$(comm -12 "$OUT/.p" "$OUT/.c" | grep -c .)

## Reflection questions

**a. Why does every filesystem-changing instruction create a layer, and in what
sense is a layer a "diff"?**

The image filesystem is built with a union/overlay filesystem (chapter 4): each
layer is a set of changes — files added, modified, deleted — stacked over the ones
below. A build instruction that touches the filesystem (RUN, COPY, ADD) captures
its result as a new layer: the *diff* between "before" and "after" that step. This
is exactly why the build cache works. Docker keys each layer on the instruction
plus the layers below it; if nothing above a given point changed, it reuses the
cached layer. Change one instruction and its layer — and every layer above it,
which was computed on top of it — is invalidated and rebuilt, while the layers
below stay untouched. Ordering a Dockerfile from least- to most-frequently-changing
is therefore a cache decision, not a stylistic one (chapter 11).

**b. Why does the sha256 config digest make the image immutable and verifiable,
and why does tagging not change it?**

The image ID is the sha256 of the config JSON, and that config lists the digests
of the layers (rootfs.diff_ids) together with the history and runtime metadata
(env, entrypoint, cmd, workdir). Because the identifier *is* a hash of the
content, you cannot alter any byte — a layer, an env var — without producing a
different digest: tampering is detectable, and "the same digest" means "byte-for-
byte the same image" anywhere in the world. A tag (myimage:1.0) is just a
human-friendly *pointer* to a digest, stored separately; re-tagging or pushing
under a new name moves the pointer but never edits the content, so the digest — the
real identity — is unchanged. This is what lets you pin a deployment to an exact
image by digest and trust you will get precisely that.

**c. Why does content-addressing let layers be shared, and how does it connect to
the cache?**

Because a layer is named by the hash of its content, two images that produced an
identical layer produce an identical digest — so the daemon stores it once and both
images point at it. In the lab the child image reuses all of the parent's layers
and adds one: on disk only the new layer costs space. The same holds over the
network: docker pull and push transfer only the digests the other side does not
already have, so pulling a new tag of an image you mostly have is nearly free. It
is the same principle as the build cache — identity by content, not by name — seen
from the storage and transport side instead of the build side. Chapter 11 turns
this from an observation into a deliberate technique: order and split layers so the
expensive, rarely-changing work is shared and cached, and only the cheap, often-
changing work is rebuilt and re-shipped.
