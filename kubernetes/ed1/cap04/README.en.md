# Chapter 4 — Dissect an Image by Hand (Anatomy of a Container)

> Exercise for **Chapter 4 — Anatomy of a Container** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- open an OCI image and recognise its three ingredients: manifest, config and layers (which are plain filesystem tarballs);
- mount an OverlayFS by hand and watch copy-on-write at work: where changes end up, how a file dies (whiteout), why a container's layer is disposable;
- prove that root in the container is not root on the host (capabilities) and that there is one single, shared kernel.

## Prerequisites

- Chapters 1-3 completed (process, namespaces, cgroups: here we add the last piece, the filesystem).
- Docker or Podman working, sudo privileges for the mount in step 4.
- About 30 MB of disk space.

## Instructions

1. Get an image and lay it bare with docker save (which exports the format that travels between registries):

       mkdir -p ~/lab-cap04 && cd ~/lab-cap04
       docker pull alpine:3
       docker save alpine:3 -o alpine.tar
       mkdir image && tar -xf alpine.tar -C image
       find image -type f

   No magic inside: a few JSON files and one or more blobs. Write down the names.

2. Read the manifest and follow the chain: which blob is the config and which is the layer?

       cat image/manifest.json

   Open the config too (the big JSON): recognise Env, Cmd and the rootfs section with the diff_ids. Write down the layer's path.

3. The layer is just a filesystem tarball: extract it and look inside.

       mkdir layer && tar -xf image/<PATH-OF-THE-LAYER> -C layer
       ls layer

   (with older versions of docker save the layer is called layer.tar inside a subfolder: the concept does not change)
   You find bin, etc, usr... an entire root filesystem. This — plus the JSON files of step 2 — IS the image.

4. Now mount an OverlayFS using the layer you just extracted as the bottom deck, and watch copy-on-write:

       mkdir upper work merged
       sudo mount -t overlay overlay -o lowerdir=layer,upperdir=upper,workdir=work merged
       ls merged
       echo "modified from the container" | sudo tee merged/etc/motd
       sudo rm merged/etc/hostname
       ls -l upper/etc/
       cat layer/etc/motd; ls layer/etc/hostname

   Observe: the change lives ONLY in upper (the "container layer"), the deleted file became a special character device in upper (the whiteout), and the layer below is untouched. This is how a hundred containers share the same image without stepping on each other.

> 💡 **No sudo?** On recent kernels you can mount the overlay inside a user
> namespace: unshare -Urm gives you a "fake root" shell (chapter 2!) where the
> mount command of step 4 works without sudo. The mount vanishes by itself
> when you exit that shell.

5. Root in the container is not root on the host. Compare the effective capabilities and try an action reserved to real root:

       docker run --rm alpine:3 grep CapEff /proc/self/status
       grep CapEff /proc/1/status
       docker run --rm alpine:3 date -s "2000-01-01"

   The two masks differ (the container's has far fewer bits), and date -s fails: CAP_SYS_TIME is missing, even though you are "root" inside.

6. The last illusion to dispel: there is only one kernel.

       uname -r
       docker run --rm alpine:3 uname -r

   Identical. Answer in writing, in the answers.md file you will submit: what does an OCI image really contain (follow the chain manifest → config → layer)? Where did the change and the deletion of step 4 end up, and why does this make containers disposable? Why can "root" in the container not change the system clock, and what does the identical uname -r inside and outside have to do with it?

7. Tear down the lab:

       sudo umount merged
       cd ~ && rm -rf ~/lab-cap04

## Definition of "done"

- [ ] You identified the config path and the layer path in the manifest, and inside the extracted layer there is a complete root filesystem.
- [ ] The change of step 4 exists only in upper, the deletion produced a whiteout, and the original layer is untouched.
- [ ] You have the two CapEff masks (different) and the failure of date -s in the container.
- [ ] uname -r inside and outside match, and answers.md answers the three questions.
- [ ] Overlay unmounted and lab folder removed.
