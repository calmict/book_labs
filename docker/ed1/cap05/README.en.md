# Chapter 5 — The chain and the custodian

**Level:** Intermediate

In Part 1 you drove namespaces, cgroups and overlay by hand. Now you open the hood of the tool that drives
them for you — and the first surprise is that "Docker" is not one program but a chain of components that
pass the work along. In this lab you follow a request from the socket to the kernel: you talk to the
daemon bare-handed, map the chain, and prove the container's parent is the shim, not the daemon. It is the
technical proof behind an important promise — you can upgrade Docker without killing your containers.

## Objectives

- Talk to the daemon directly over the socket with curl: the CLI is just an API client (5.2).
- Verify the same API lists the containers, as docker ps would (5.1, 5.2).
- Map the chain and prove the container's parent is a containerd-shim, not dockerd (5.3, 5.5).
- Understand why systemd/containerd, not the daemon, sits above the shim: the basis of live-restore (5.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md) and curl. Your user must be able to use Docker (in
  the docker group) — but remember chapter 23: that permission equals root.
- Part 1 as the foundation: here you will see runc automate the very namespaces, cgroups and overlay you
  mounted by hand.

## The scenario

In start/ you will find lacatena.sh: a script that should follow a request from the API to the chain, but
does not yet record the information that matters. You fill three gaps (TODO 1..3) using a throwaway
container, never restarting the shared daemon.

Prepare the environment:

    cd docker/ed1/cap05/start

### Phase 1 — The single-command misconception (5.1)

When you type docker run, instinct says "the docker program started the container". It is false: docker
is only a client that turns your request into an API call and sends it to the dockerd daemon. It is the
daemon, not the client, that owns containers, images and networks.

### Phase 2 — The socket is the API (5.2 — TODO 1)

Open start/lacatena.sh and complete **TODO 1**: ask the daemon its version by talking straight to the
UNIX socket with curl, and record it —

    ver=$(curl -s --unix-socket "$SOCK" http://localhost/version \
            | grep -o '"Version":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "api_version=$ver" > "$OUT/chain.txt"

Every docker command is, at bottom, an HTTP request to this socket.

### Phase 3 — The custodian: the container's parent (5.5 — TODO 2)

The script starts a throwaway container and finds its PID on the host. Complete **TODO 2**: record the
name of the PARENT process, read from /proc/<ppid>/comm. It will be a containerd-shim — the custodian —
not dockerd.

    echo "parent_comm=$(cat "/proc/$ppid/comm")" >> "$OUT/chain.txt"

### Phase 4 — Above the shim (5.4 — TODO 3)

Complete **TODO 3**: step one level up and record the name of the GRANDPARENT process (the parent's
parent, from field 4 of /proc/<ppid>/stat). It is systemd or containerd, not dockerd: the proof that the
container is not a child of the daemon, and that is why restarting dockerd does not kill it.

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- lacatena.sh records the version obtained from the socket (TODO 1).
- It records the container's parent (a shim) (TODO 2).
- It records the grandparent (systemd/containerd, not dockerd) (TODO 3).
- run.sh prints OK 1..4 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh follows the chain and checks, point by point:

- **OK 1** — the CLI is an API client: the raw socket answers with the daemon version.
- **OK 2** — the same API lists the running container (the CLI just formats it).
- **OK 3** — the container's parent is the custodian shim, not the daemon.
- **OK 4** — above the shim is systemd/containerd, not dockerd: this is why live-restore works.

## Reflection questions

**a.** docker is only a client. How did you prove it with curl? Why is the typical error "Cannot connect
to the Docker daemon" and not "docker is broken"? And why does writing to that socket equal being root on
the host (chapter 23)?

**b.** If runc creates the container and then exits, who keeps it alive? Answer with the evidence from the
process tree (parent and grandparent), and explain why this makes it possible to upgrade the daemon
without stopping the containers — live-restore.

**c.** To watch live-restore for real you enable it and restart the daemon (systemctl restart docker with
live-restore: true). Why does this lab NOT automate that step? In which environment is it safe to try,
and how would you isolate it on a shared machine?

## Cleanup

Nothing to tear down: the throwaway container is started with --rm and removed by the script (trap) at the
end; the test works in a temporary directory it cleans up itself. The daemon is never restarted, so no
other container on the host is touched.

## Where it leads

You turned "Docker" from a black box into a readable chain. **Chapter 6** steps aside to understand why
this chain is made of interchangeable parts: the OCI standards, and the config.json file that runc reads
and executes — the exact recipe into which all of Part 1 condenses.
