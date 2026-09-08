# Chapter 4 - Dissect an image by hand - answers

## The completed TODOs

TODO 1 (4.2) reads the paths selected by the image manifest:

    config_path=$(jq -r '.[0].Config' image/manifest.json)
    layer_path=$(jq -r '.[0].Layers[0]' image/manifest.json)

TODO 2 (4.1) extracts the layer and mounts it below upper and work directories.
The script changes merged/etc/motd and removes merged/etc/hostname, then proves
that the lower checksums and files did not change while upper contains the copy.

TODO 3 (4.3, 4.4) captures CapEff and uname -r on both sides and attempts date -s
inside the container. The clock operation is refused even though the process has
uid 0.

## Reflection answers

a. An OCI image contains metadata plus filesystem tarballs. The manifest points
to the config and ordered layers; the config supplies runtime defaults and the
rootfs diff IDs; each layer contains filesystem changes.

b. The changed motd is copied into upper and the deleted hostname is hidden by
an OverlayFS whiteout. Lower remains unchanged, so many containers can share the
image and discard only their private writable layer.

c. Container root lacks CAP_SYS_TIME, so it cannot change the single system
clock. Identical uname -r output shows why: host and container use the same
kernel, even though namespaces restrict the container's view.

d. No. The powers are cut, the identity is not. uid_map reads "0 0 ...": uid 0
inside maps to uid 0 outside, and the node reports Uid 0 for that very process.
Capabilities decide what uid 0 may do; only a user namespace changes who it is,
by remapping the range - and it is off by default here. That is why a container
escape lands on a real uid 0, and why the two mechanisms are quoted together
when the chapter says root in the container is not root on the host.
