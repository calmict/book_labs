# Chapter 5 — Answers (model solution)

## The parent chain

    1419511 sleep             <- the container process
    1419489 containerd-shim   <- its ONLY ancestor below PID 1
    (next parent: PID 1)

## containerd, queried directly

    # sudo ctr --namespace moby task ls
    TASK                                                              PID      STATUS
    83f3a...(the docker container ID)...                              1419511  RUNNING

(same PID seen in step 2: one process, three points of view — docker, the
kernel, containerd)

## The OCI bundle

    config.json sections found:
    - "namespaces": pid, network, ipc, uts, mount   -> chapter 2
    - "resources":  the cgroup knobs                -> chapter 3
    - "capabilities" and "root"/rootfs              -> chapter 4

## The three questions

**a. Who is the direct parent of the container process, why do neither
dockerd nor containerd appear in the chain, and what is the shim for?**

The direct parent is the containerd-shim, whose own parent is PID 1 — the
chain ends there. Dockerd and containerd are running, but as bystanders: they
asked for the container, they do not hold it. The shim exists precisely to
break the ancestry: it keeps the container's stdio and exit status on behalf
of containerd, so the daemons can restart or upgrade without their death
taking every container down with them. If the chain were
dockerd → containerd → process, restarting the daemon would kill every
workload on the machine.

**b. Reconstruct who calls whom when you type docker run, and explain what
the "moby" drawer seen through ctr demonstrates.**

docker (CLI) sends an API request to dockerd; dockerd delegates container
lifecycle to containerd; containerd prepares the OCI bundle, starts a shim
for the container, and the shim invokes runc, which creates the process and
exits. Seeing your container inside containerd's "moby" namespace with ctr —
without docker in the loop — demonstrates that docker is one client among
many: the actual owner of running containers is containerd. Kubernetes takes
this same seat with the CRI, which is why Docker could be "removed" without
containers noticing.

**c. Where in config.json did you find the ingredients of chapters 2-4?
And what happens to runc after it has started the container?**

The namespaces array lists exactly the kernel namespaces built by hand in
chapter 2; the linux.resources section carries the cgroup limits of chapter
3; the capabilities lists and the root section (the rootfs path) are chapter
4. The bundle is those three chapters written down as a contract. As for
runc: it creates the container and terminates — in the grand finale it
returned to the prompt as soon as the command inside finished. It is a
one-shot executor, not a daemon; whoever needs to babysit the container
(the shim) stays, the runtime that built it leaves.
