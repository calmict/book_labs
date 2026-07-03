# Chapter 5 — Climb the Runtime Chain (and Run a Container with runc Alone)

> Exercise for **Chapter 5 — The Runtime War: Docker, containerd, CRI-O** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- climb the real process chain of a running container and discover who is actually there (and who is NOT) between it and init;
- query containerd directly, bypassing Docker, to see firsthand that the docker command is just a client;
- read an OCI bundle (the config.json that containerd prepares for runc) and recognise in it the namespaces, cgroups and capabilities of chapters 2-4;
- start a container with runc alone: no daemons, no API, just the spec and a rootfs.

## Prerequisites

- Chapters 1-4 completed (all the pieces that you will now see assembled into a chain).
- Docker working; runc and ctr are already on the system (they ship with Docker's containerd package: check with command -v runc ctr).
- Sudo privileges for steps 4 and 5.

> 💡 **Using Podman?** You will see a different story, and that is the point of
> §5.5: no daemon, the container's parent is conmon. Steps 2-5 will not match,
> but redoing them on Podman and comparing the two chains is an excellent
> extra exercise. Step 6 (pure runc) works identically.

## Instructions

1. Start the lab container:

       docker run -d --name lab-cap05 alpine:3 sleep infinity

2. Climb the parent chain, from the container process up to PID 1, reading /proc by hand (the fourth field of /proc/[pid]/stat is the parent):

       PID=$(docker inspect --format '{{.State.Pid}}' lab-cap05)
       P=$PID; while [ "$P" -ne 1 ]; do ps -o pid=,comm= -p "$P"; P=$(awk '{print $4}' /proc/$P/stat); done

   Write the chain down. Surprise: between your sleep and init there is ONE single link, the containerd-shim. Confirm with pstree -s -p $PID.

3. What about the two big names? Check that dockerd and containerd are indeed running:

       ps -e -o pid,comm | grep -E 'dockerd|containerd'

   They run, but they are NOT ancestors of your container. First question to note down: why is the shim's parent PID 1 and not containerd? What would happen to the containers, on a daemon restart, if the chain were dockerd → containerd → process?

4. Docker is just a client: talk to containerd directly and find your container again:

       sudo ctr --namespace moby task ls

   There it is: containerd manages it, docker merely asked for it. The "moby" namespace is the name Docker uses to introduce itself to containerd (and it has nothing to do with the kernel namespaces of chapter 2: here it is just a logical drawer inside containerd).

5. The OCI Runtime Spec in the flesh. The "bundle" containerd prepared for runc is on disk:

       ID=$(docker inspect --format '{{.Id}}' lab-cap05)
       sudo ls /run/containerd/io.containerd.runtime.v2.task/moby/$ID/
       sudo cat /run/containerd/io.containerd.runtime.v2.task/moby/$ID/config.json

   In the JSON (it is long: scroll through it calmly, or open it with less) find the three previous chapters again: the namespaces section (chapter 2), the cgroup resources (chapter 3), capabilities and the rootfs (chapter 4). This file IS the standard contract: anyone who honours it can act as a runtime.

6. The grand finale: a container with runc alone, no daemon at all. Prepare your own bundle (docker export flattens the container's filesystem into a single tar: note the difference from chapter 4's docker save, which preserves the layers):

       mkdir -p ~/lab-cap05/bundle/rootfs && cd ~/lab-cap05/bundle
       docker create --name lab-cap05-exp alpine:3
       docker export lab-cap05-exp | tar -x -C rootfs
       docker rm lab-cap05-exp
       runc spec --rootless
       runc run demo

   You are inside a shell of the container (new prompt, hostname "runc"): look around with ps aux — PID 1 again! — then leave with exit. The container dies with the shell: runc is a one-shot executor, not a daemon.

7. Answer in the answers.md file you will submit (questions below), then tear down the lab:

       docker rm -f lab-cap05
       cd ~ && rm -rf ~/lab-cap05

   The three questions for answers.md: (a) who is the direct parent of the container process, why do neither dockerd nor containerd appear in the chain, and what is the shim for? (b) reconstruct who calls whom when you type docker run (CLI → dockerd → containerd → shim → runc → process) and explain what the "moby" drawer seen through ctr demonstrates; (c) where in config.json did you find the ingredients of chapters 2-4 again? And what happens to runc after it has started the container?

## Definition of "done"

- [ ] You have the parent chain written down: process → containerd-shim → PID 1, with dockerd and containerd alive but outside the chain.
- [ ] You saw your container listed by ctr in the moby namespace, without going through docker.
- [ ] In config.json you located the namespaces, resources (cgroup) and capabilities sections.
- [ ] The container started with runc run came up, you entered it (PID 1) and closed it with exit.
- [ ] answers.md answers the three questions and the lab is torn down.
