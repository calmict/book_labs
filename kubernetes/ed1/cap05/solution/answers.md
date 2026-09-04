# Chapter 5 - Climb the runtime chain - answers

## The completed TODOs

TODO 1 (5.2) starts from the host PID reported by docker inspect and repeatedly
reads the fourth field of proc/PID/stat. The resulting chain is workload,
containerd-shim, then PID 1.

TODO 2 (5.1, 5.3) runs ctr in the moby namespace and copies the live config.json.
When the host socket rejects the regular user, a non-privileged helper reads the
same socket and a read-only task-directory mount.

TODO 3 (5.3) exports a rootfs, generates a rootless OCI spec, selects a
non-interactive command that prints its PID, and starts it directly with runc.

## Reflection answers

a. The direct parent is containerd-shim. It preserves standard streams and exit
status and keeps the workload independent from daemon restarts. Dockerd and
containerd requested the process but are not its ancestors.

b. The path is Docker CLI, dockerd, containerd, shim, runc, process. Finding the
same PID with ctr in the moby namespace shows that containerd owns the task and
Docker is one high-level client. The moby name is a logical containerd namespace,
not a Linux kernel namespace.

c. The OCI config stores namespaces in linux.namespaces, cgroup settings in
linux.resources, capabilities in process.capabilities, and the filesystem in
root.path. Runc creates the process and exits; the shim remains to supervise it.
