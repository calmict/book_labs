# Chapter 18 — Answers (model solution)

## The naive rename (Phase 0)

    # docker_container.app will be destroyed
    # docker_container.frontend will be created

## moved (Phase 1)

    # docker_container.app has moved to docker_container.frontend
    Plan: 0 to add, 0 to change, 0 to destroy.
    # container ID before == after (not recreated)

## removed and import (Phases 2-3)

    # docker_container.cache will be removed from the OpenTofu state but will not be destroyed
    # cache container status after apply: running
    # docker_volume.data will be imported
    Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.  ->  then: No changes.

## The three questions

**a. The address is the identity.**

Terraform does not identify a resource by its real attributes (name, image,
port) — it identifies it by its ADDRESS in the state, docker_container.app. The
state (chapter 11) is a map: address -> real object. When I rename the label from
app to frontend, the address docker_container.app vanishes from the desired
config and a brand-new address docker_container.frontend appears. Terraform
diffs by address: it sees one address with no config (so: destroy) and one config
with no state (so: create). The fact that the two describe the identical real
container is irrelevant — nothing in the model links the old address to the new
one. That is why the naive rename is a demolish-and-rebuild: not because anything
real changed, but because the key the whole notebook is indexed by changed.

**b. removed versus a destroy.**

Removing a resource from the code WITHOUT a removed block: the address is now in
the state but absent from config, so Terraform plans to destroy it — the
container is stopped and deleted. Removing it WITH a removed block: Terraform is
told to drop the address from the state and leave reality alone — the container
keeps running, it is simply no longer managed. So: without the block, the
container dies; with the block, it survives, orphaned but alive. The syntax
differs because the two tools implemented the feature differently: OpenTofu's
removed block forgets by default (bare removed { from = ... }), while Terraform
requires an explicit lifecycle { destroy = false } inside the block (and can also
express destroy = true to actually delete). Same outcome for our case — forget
without destroying — reached through two dialects; a reminder that "one language,
two binaries" is true in the large but has a few seams.

**c. import and the scalpel.**

The volume import said 0 to change because the resource I wrote
(docker_volume.data with name cap18-data) matches the real object exactly: a
volume has almost no attributes, so what I declared and what exists are the same,
and import adopts it cleanly. A hand-made container forces a replace because the
kreuzwerker/docker provider cannot fully reconstruct a container's arguments from
a running instance (env comes back as computed and is ForceNew, the image is
recorded as a tag rather than the id my config references), so the imported state
disagrees with the config on a replace-forcing attribute — adoption reveals drift
I must reconcile. The general lesson: import binds an address to an existing
object, but you still owe a config that MATCHES it, or the next plan will try to
fix the mismatch. And why blocks beat state commands: moved/removed/import live in
the code and produce a PLAN — the change is reviewable, diffable, version
controlled, and applied the same way in CI as everything else. tofu state mv/rm
act immediately on the state with no plan, no review, no record: a powerful
scalpel, but one that cuts silently. You reach for the commands only for the
one-off a block cannot express.
