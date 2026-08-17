# Chapter 32 — Your Container, from the First Line

> Exercise for **Chapter 32 — A Container by Hand, Without Docker** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Advanced

## Objectives

By the end of this lab you will be able to:

- build a base filesystem in a temporary directory;
- combine user, PID, network, UTS, mount, and IPC namespaces without host privileges;
- replace the root with pivot_root and mount proc only inside the new root;
- enforce CPU and memory limits through a delegated cgroup v2 subgroup;
- connect the container to an isolated host side with a veth pair;
- trigger bounded CPU saturation and an OOM event while proving that host processes remain invisible.

## Prerequisites

- A Linux host with unprivileged user namespaces and a unified cgroup v2 hierarchy.
- An active systemd user session that allows scopes with Delegate=yes.
- Bash, util-linux, iproute2, procps, debootstrap, and timeout.
- Network access to build a minimal Debian filesystem and about 500 MiB of temporary disk space.

## Instructions

1. Copy the start directory to a working directory and complete observations.md.
2. Create a temporary directory and build a minimal filesystem inside it with debootstrap. Never reuse an existing host root filesystem.
3. Start the lab controller in an explicitly delegated user scope. Create labcap32-container inside that scope, then set cpu.max to 50000 100000, memory.max to 96 MiB, memory.swap.max to zero, and memory.oom.group to one.
4. First create an unprivileged outer network namespace to represent the host side of the lab. From there, start the container with the complete command:

       unshare --user --map-root-user --pid --net --uts --mount --ipc --propagation private --fork ./container-init.sh

   The host side is itself isolated from the real network. This second boundary makes it possible to configure the veth without privileges and without changing real host interfaces or routes.
5. Connect labcap32-host to labcap32-guest with a veth pair. Assign 10.200.32.1/24 to the isolated host side and 10.200.32.2/24 to the container, bring loopback up, and verify the link with ping.
6. In the new mount namespace, bind-mount the root filesystem, call pivot_root, unmount the old root, and only then mount proc inside the new root.
7. Inside the container, verify that the shell is PID 1, that /.oldroot is absent, and that a labcap32-host-sentinel process started outside the PID namespace does not appear in ps.
8. Saturate the CPU for three seconds under timeout and observe the increase in nr_throttled. Finally, write 160 MiB to a tmpfs while memory.max is 96 MiB: the group must encounter an OOM kill without affecting the control process.
9. Record the counters and observations, then remove the veth, processes, cgroup, filesystem, mounts, and temporary directory.

The solution directory contains an executable solution:

    ./solution/run.sh

## Definition of "done"

- [ ] The filesystem was built in a temporary directory and pivot_root made the old root unreachable.
- [ ] The container uses every required namespace and proc was mounted only after pivot_root.
- [ ] The labcap32-host and labcap32-guest pair connects the container to the isolated host side without changing the real network.
- [ ] The host sentinel process is not visible from the container.
- [ ] cpu.stat reports throttling and memory.events reports an OOM kill in the limited cgroup.
- [ ] Every workload is short and bounded; no process, cgroup, mount, interface, or temporary file remains afterward.
