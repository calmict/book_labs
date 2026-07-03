# Chapter 2 — A Container by Hand, Without Docker

> Exercise for **Chapter 2 — Linux Namespaces: The Art of Illusion** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- build a working "container" using only basic Linux tools (unshare, chroot), with no container runtime at all;
- recognise namespaces as the real ingredient of the illusion: PID 1, private hostname, isolated network;
- read and compare the files under /proc/[pid]/ns to prove, inode by inode, that two processes live in different namespaces.

## Prerequisites

- Chapter 1 completed (the "same process, two views" concept).
- A Linux host with sudo privileges; you need unshare (util-linux package) and wget or curl.
- About 10 MB of disk space for the mini rootfs.
- Note: unlike chapter 1, this exercise works on WSL2 with no special care — no daemon is involved here, you talk to the kernel directly.

> 💡 **No sudo?** You can do everything as a regular user: drop sudo from
> step 2 and add the options --user --map-root-user right after unshare.
> That is the USER namespace of §2.2.6 in action: it gives you a "fake root"
> valid only inside the container, and it is the same mechanism behind
> Podman's rootless containers.

## Instructions

1. Prepare the working folder and download the Alpine mini rootfs (any recent version works; we pin one for reproducibility):

       mkdir -p ~/lab-cap02/rootfs && cd ~/lab-cap02
       wget https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-minirootfs-3.24.1-x86_64.tar.gz
       tar -xzf alpine-minirootfs-*.tar.gz -C rootfs

2. Create the container by hand: new PID, mount, UTS, IPC and network namespaces, with the filesystem root inside rootfs:

       sudo unshare --pid --fork --mount --uts --ipc --net chroot rootfs /bin/sh

   You are now in a shell "inside" the container. Keep it open: the next steps are done from here and from a second terminal on the host.

3. Inside the container, fix the PATH (the chroot inherits the host's, which may not include the right Alpine directories), mount /proc and look at the process tree:

       export PATH=/usr/sbin:/usr/bin:/sbin:/bin
       mount -t proc proc /proc
       ps aux

   Write down what you see: how many processes are there, and what PID does your shell have?

4. Still inside, change the hostname and verify UTS and network isolation:

       hostname hand-made-container && hostname
       ip addr

   From the second terminal on the host, verify that the host's hostname has NOT changed, and compare ip addr: inside there is only a loopback interface, down; outside, your real network.

5. Now prove, inode by inode, that the two worlds live in different namespaces (this is §2.5 of the manual made tangible). Inside the container, where your shell is PID 1:

       for ns in pid uts net user; do echo "$ns: $(readlink /proc/$$/ns/$ns)"; done

   And from the second terminal on the host, the exact same command:

       for ns in pid uts net user; do echo "$ns: $(readlink /proc/$$/ns/$ns)"; done

   Same command, two different answers: compare the inode numbers between the two series. Which ones differ? Is any of them the same?

6. Answer in writing, in the answers.md file you will submit: in what sense is your unshare command conceptually equivalent to the docker run of chapter 1? What did you NOT get compared to a real container (images and layers, resource limits, security)? Why is the --fork option needed together with --pid?

7. Tear down the lab: exit the container shell (exit) and remove the folder:

       rm -rf ~/lab-cap02

## Definition of "done"

- [ ] Inside the container, ps aux shows your shell as PID 1 and an almost empty process list.
- [ ] The hostname inside is "hand-made-container" and the host's hostname is untouched.
- [ ] You have the /proc/[pid]/ns inode comparison: pid, uts and net differ between container and host. And you noticed the user case: identical in the sudo variant (we did not isolate it), different in the rootless variant (it is the namespace that makes all the others possible without root).
- [ ] Your answers.md file answers the three questions of step 6.
- [ ] The lab folder has been removed.
