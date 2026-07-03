# Chapter 4 — Answers (model solution)

## The image laid bare

    image/index.json
    image/oci-layout
    image/manifest.json
    image/blobs/sha256/d529dd0c...  <- config (the big JSON: Env, Cmd, rootfs)
    image/blobs/sha256/55afa1ec...  <- layer (a plain filesystem tarball)
    (plus a few small metadata blobs of the OCI layout)

## Copy-on-write: the evidence

    --- upper/etc after the change and the deletion ---
    c---------. 2 root root 0, 0  hostname   <- the whiteout
    -rw-r--r--. 1 root root   28  motd       <- the modified copy
    --- the lower layer, untouched ---
    layer/etc/hostname still exists, layer/etc/motd still says
    "Welcome to Alpine!"

## Capabilities and kernel

    container CapEff: 00000000a80425fb   (the default docker bounded set)
    host root CapEff: 000001ffffffffff   (all capabilities)
    date -s inside:   date: can't set date: Operation not permitted
    uname -r host:      5.14.0-...x86_64
    uname -r container: 5.14.0-...x86_64  (identical)

(exact digests, masks and kernel versions vary with your image and distro;
what matters is the chain, the whiteout, and the difference between the two
masks. Note that busybox's date prints the refusal but still exits 0: the
evidence is the error message, not the exit code)

## The three questions

**1. What does an OCI image really contain? Follow the chain
manifest → config → layer.**

Three kinds of plain files. The manifest is the entry point: it says which
blob is the config and which blobs are the layers, addressed by digest. The
config is a JSON with the runtime defaults (Env, Cmd, working dir...) and the
rootfs section listing the diff_ids of the layers in order. Each layer is
nothing more than a tarball of a filesystem tree. There is no executable
"image object": an image is metadata plus stacked tarballs, which is exactly
why a registry is just a blob store.

**2. Where did the change and the deletion of step 4 end up, and why does
this make containers disposable?**

Both ended up exclusively in upper, the writable layer that overlay puts on
top of the read-only image layers. The modified motd is a full copy made at
write time (copy-up); the deleted hostname became a whiteout, a marker that
hides the file below without touching it. The image layer stayed read-only
and byte-identical, so it can be shared by any number of containers. Throw
the upper directory away and the container is factory-new: that is the whole
"disposable container" model — persistent data must live elsewhere (volumes).

**3. Why can "root" in the container not change the system clock, and what
does the identical uname -r inside and outside have to do with it?**

Because there is only one clock, owned by the only kernel — the host's, as
the identical uname -r proves. The runtime starts the container's root with a
reduced capability set: CAP_SYS_TIME is not in the default mask, so setting
the clock is refused even for uid 0. Full root could change the time for the
whole machine, every container included, since the kernel is shared. Root in
the container is an isolated, de-fanged root: namespaces limit what it sees
(chapter 2), cgroups what it consumes (chapter 3), capabilities what it may
do — and the shared kernel is the reason all three cages are needed.
