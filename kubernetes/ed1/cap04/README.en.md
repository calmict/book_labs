# Chapter 4 — Dissect an image by hand

**Level:** Foundational

After namespaces and cgroups, one last piece of the anatomy is missing: the filesystem. In this lab you
open an image, follow the references between its objects, and measure how - and in what sense -
container root differs from host root: in its powers, yes; in its identity, no.

## Objectives

- Recognise the manifest, config, and layers of an OCI image (4.2).
- Observe copy-up, whiteouts, and lower-layer immutability with OverlayFS (4.1).
- Compare capabilities and the kernel inside and outside the container (4.3, 4.4).

## Prerequisites

- A Linux host with Docker, jq, tar, sha256sum, mount, and unshare.
- Support for unprivileged user namespaces; neither sudo nor host mounts are required.
- About 30 MB of temporary disk space.

## The scenario

In start/image-lab.sh you will find a valid but incomplete script. Fill three gaps: follow the manifest,
build the OverlayFS view, and collect evidence about the boundary between container and host.

    cd kubernetes/ed1/cap04/start

### Phase 1 — Follow the addresses (4.2 — TODO 1)

Read image/manifest.json with jq and save the Config path and first Layers entry in image.env. Do not
choose blobs by name: the manifest establishes the chain.

### Phase 2 — Write without changing the image (4.1 — TODO 2)

Extract the layer, then mount an OverlayFS with lowerdir, upperdir, and workdir inside unshare -Urm.
Change etc/motd and remove etc/hostname in the merged view; record checksums and file presence before
and after.

### Phase 3 — Root with limited powers (4.3, 4.4 — TODO 3)

Compare PID 1's CapEff with the process inside the container, attempt date -s in the container, and
compare uname -r. Then look at identity, which is a separate mechanism: the uid the container reports
for itself, the first line of its /proc/self/uid_map, and the uid the node sees for that same process.
Record the results in isolation.env, then run:

    cd ../solution
    ./run.sh

## Definition of "done"

- The three TODOs are complete and the generated files identify real objects.
- The lower layer remains unchanged after the modification and deletion in the merged view.
- The attempt to change the clock is refused and the kernels match.
- The uid seen by the node matches what the container's uid_map predicts.
- run.sh prints OK 1..6 and ALL CHECKS PASSED.

## How it is verified

- OK 1 follows the manifest, config, and layer and validates the config and rootfs sections.
- OK 2 checks copy-up, deletion, and lower-layer immutability.
- OK 3 checks different capabilities and the refusal from date -s.
- OK 4 checks that the uid seen by the node is the one uid_map predicts, and prints both uids.
- OK 5 compares the kernel versions.
- OK 6 is the gate: without upperdir, the modification must fail.

## Reflection questions

**a.** What does an OCI image really contain, and how do you follow the manifest, config, and layer chain?

**b.** Where do the modification and deletion end up, and why does this make the container layer disposable?

**c.** Why can container root not change the clock, and how does that relate to the shared kernel?

**d.** The container has fewer powers than host root: does it also have a different identity? What does
uid_map say, and what would it take to change it for real?

## Cleanup

run.sh uses a temporary directory and the mount lives in a user namespace that ends on its own. The
trap removes every file; no containers or host mounts remain.

## Where it leads

You opened the package and recognised the mechanisms that isolate it. Chapter 5 follows who assembles
these pieces: containerd prepares the OCI bundle and runc creates the process.
