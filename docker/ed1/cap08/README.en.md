# Chapter 8 — The manifest

**Level:** Intermediate

With the engine's architecture behind us, the craft begins: images. And the first
surprise is that an image is not a monolithic block but a **stack of layers** plus
a **manifest** that lists them — just as a ship is not a hull filled at random but
stacked containers and a manifest saying what is aboard and in what order. In this
lab you dissect an image bare-handed: you count its layers, read the sha256 digest
that seals it, and prove why two different images share the same layers without
copying them.

## Objectives

- See that an image is a config plus a stack of layers, and that every instruction
  touching the filesystem adds a layer (8.1, 8.2).
- Read the image ID as the **sha256 digest of the config**: the image is
  identified by its content, hence immutable and verifiable (8.3).
- Recognise layers as **content-addressed** diffs (each one a digest) (8.2).
- Prove **sharing**: an image built on top of another reuses the same layers,
  without duplicating them — the basis of the cache and of pull by digest (8.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Part 2 as context: you know who runs a container and by which rules; here you
  see where the rootfs that runc mounts comes from.

## The scenario

In start/ you will find lanatomia.sh: a script that builds a small image (busybox
plus two instructions that each write a file) and should record its anatomy, but
the three key measurements are not taken yet. You fill three gaps (TODO 1..3)
using throwaway images, never touching the shared daemon.

Prepare the environment:

    cd docker/ed1/cap08/start

### Phase 1 — An image is a stack of layers (8.1, 8.2)

The script builds the image with a minimal Dockerfile: from busybox, two RUN
instructions that each write a file. Every instruction that changes the filesystem
produces a new layer on top of the previous ones. The busybox base is a single
layer: the final image will have one for the base plus two for the two RUNs.

### Phase 2 — Counting the layers (8.2 — TODO 1)

Open start/lanatomia.sh and complete **TODO 1**: record the number of layers of
the image and of the base, reading them from the config with docker image inspect
(the rootfs.diff_ids field is exposed as .RootFS.Layers) —

    layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$TAG")
    base_layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$BASE")

### Phase 3 — The digest that seals (8.3 — TODO 2)

Complete **TODO 2**: record the image ID (the sha256 digest of the config) and the
digest of the top layer. Both are content addresses: change one byte and the
digest changes.

    image_id=$(docker image inspect -f '{{.Id}}' "$TAG")
    top_layer=$(docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG" | grep '^sha256' | tail -1)

### Phase 4 — Layer sharing (8.4 — TODO 3)

Complete **TODO 3**: build a second image starting from the first (one more RUN),
then count how many of the first image's layers reappear identical in the second.
Content-addressing means shared layers are not duplicated.

    docker build -q -t "$TAG-child" - >/dev/null <<EOF
    FROM $TAG
    RUN echo three > /three.txt
    EOF
    child_layers=$(docker image inspect -f '{{len .RootFS.Layers}}' "$TAG-child")
    docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG" | grep '^sha256' | sort > "$OUT/.p"
    docker image inspect -f '{{range .RootFS.Layers}}{{println .}}{{end}}' "$TAG-child" | grep '^sha256' | sort > "$OUT/.c"
    shared=$(comm -12 "$OUT/.p" "$OUT/.c" | grep -c .)

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- lanatomia.sh records the number of layers of the image and of the base (TODO 1).
- It records the image ID and the digest of the top layer (TODO 2).
- It builds the child image and counts the shared layers (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh builds the images and checks, point by point:

- **OK 1** — the image has one layer for the base plus one for each of the two
  RUNs: layers = base_layers + 2.
- **OK 2** — the image ID is a sha256 digest (of the config) and the top layer is
  itself a sha256 digest: the image is content-addressed.
- **OK 3** — the child image has exactly one more layer than the first and reuses
  all of its layers (shared = the first image's layers): the layers are shared,
  not copied.

## Reflection questions

**a.** Why does every instruction that changes the filesystem create a new layer,
and in what sense is a layer a "diff"? Connect the answer to the build cache: why
does changing one instruction invalidate that layer and all above it, but not the
ones below?

**b.** The image ID is the sha256 digest of the config, and the config lists the
digests of the layers (rootfs.diff_ids) plus the history and metadata (env,
entrypoint). Why does this make the image immutable and verifiable, and why does
"tagging" an image not change it?

**c.** The child image reuses all of the first's layers. Why does content-
addressing let layers be shared on disk and over the network (pull and push move
only the missing digests)? And how does this connect to the strategic cache of
chapter 11?

## Cleanup

Nothing to tear down by hand: the two test images are removed by the script
(docker rmi, plus a safety trap) at the end; the test works in a temporary
directory it cleans up itself. The busybox base image stays in cache (it is
shared, and later chapters need it). No container started, the daemon is never
restarted.

## Where it leads

You took an image apart into its pieces: config, digest, stack of layers.
**Chapter 9** goes the other way and has you **build** it with intent — the
fundamental Dockerfile instructions, and how each becomes one of the layers you
just counted. For a quick reference on Dockerfile and commands, see the volume's
appendices.
