# Chapter 26 — The black box of the mute container

**Level:** Cloud Architect

Sooner or later comes the container that will not start, says nothing, and maybe keeps
restarting on its own. The logs are empty — mute — and the instinct is to give up. But a
container is never truly mute: even when it writes not a line, it leaves a black box.
docker inspect tells how it died — the exit code, which as you saw in chapter 7 is already
a diagnosis — and how many times it restarted before giving up, the mark of a crash loop.
In this lab you reconstruct the story of containers with different symptoms: a silent
crash, an OOM kill, a missing command and an image without a shell. The diagnosis starts
from observable facts and leads to a targeted remedy each time.

## Objectives

- Recognise a "mute" container: the logs are empty, there is nothing to read there (26.1).
- Read the black box with docker inspect: the exit code, the real diagnosis (26.2, 26.4).
- Recognise the crash loop from the restart counter and the final state (26.3).
- Connect the exit code to its causes (chapter 7): 42, 137, 143, 127... (26.4).
- Confirm an OOM kill with exit 137 and State.OOMKilled, not with the number alone (26.4).
- Distinguish the 127 returned by a shell from rejection of a missing direct executable
  (26.4).
- Observe a shellless container's processes by sharing its PID namespace (26.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use Docker.
- Chapter 7 (lifecycle and exit codes) and 25 (logs and metrics): here you use them when
  something goes wrong.

## The scenario

In start/ you will find troubleshoot.sh: a script that starts a container which exits silently
with a non-zero code and a restart policy, and should read its logs, exit code and
restarts — but the three reads are missing. The script then extends the diagnosis to three
more symptoms. You fill six gaps (TODO 1..6). Containers and image are throwaway; the daemon
is not touched.

Prepare the environment:

    cd docker/ed1/cap26/start

### Phase 1 — The silence: empty logs (26.1 — TODO 1)

Open start/troubleshoot.sh and complete **TODO 1**: read the container's logs. They are empty: the
container died without printing anything. From the logs, here, you get nothing.

    logs=$(docker logs "$C" 2>&1)

### Phase 2 — The black box: the exit code (26.2, 26.4 — TODO 2)

Complete **TODO 2**: read the exit code from docker inspect. Even without logs, the exit
code is already a diagnosis — here 42, an application error.

    exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$C")

### Phase 3 — The crash loop: the restarts (26.3 — TODO 3)

Complete **TODO 3**: read how many times the container restarted and its final state. With
a restart policy, a container that crashes at once restarts in a loop until the policy
gives up.

    restart_count=$(docker inspect -f '{{.RestartCount}}' "$C")
    status=$(docker inspect -f '{{.State.Status}}' "$C")

### Phase 4 — Exit 137: killed, not "failed" (26.4 — TODO 4)

Complete **TODO 4**: start a process with a 16 MiB memory ceiling and make it request a
64 MiB buffer. Wait for it to stop, then read both State.ExitCode and State.OOMKilled from
docker inspect. The value 137 is 128+9, so it signals SIGKILL; only OOMKilled=true attributes
the signal to exhausted memory here.

The remedy is to fix or constrain the application's allocation and size the ceiling from
measured consumption, rather than raising it blindly.

    oom_exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$OOM_C")
    oom_killed=$(docker inspect -f '{{.State.OOMKilled}}' "$OOM_C")

### Phase 5 — Exit 127: the command that is not there (26.4 — TODO 5)

Complete **TODO 5**: run the same missing command first through sh -c and then directly.
In the first case a shell starts, cannot find the command and returns 127; State.Error stays
empty. In the second case Docker cannot start the process: the container remains in the
created state and State.Error explains the rejection. The client return code does not turn
the second case into a shell exit.

The remedy is to correct CMD or ENTRYPOINT and verify that the binary exists in the image
and is reachable through PATH; if a shell feature was intended, explicitly invoke a shell
that is present in the image.

    shell_exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$SHELL_C")
    direct_error=$(docker inspect -f '{{.State.Error}}' "$DIRECT_C")

### Phase 6 — Looking inside a container without a shell (26.4 — TODO 6)

Complete **TODO 6**: have the script write the Dockerfile below, build a small scratch image
containing only the static sleep binary, prove that docker exec cannot start sh in it, then
launch a helper container that shares the target's PID namespace and runs ps from outside.
The script writes the Dockerfile because run.sh creates the working directory afresh on every
run: in the heredoc, the body and the closing EOF must start at column 0.

This unprivileged route shows the process list, but **not** the target filesystem, and it
does not replace nsenter in general. The operational remedy is to use a separate debugging
image with the necessary tools, without adding a shell to the production image; filesystem
or additional namespaces require suitable techniques and privileges.

    FROM busybox:1.36.1-uclibc AS source
    FROM scratch
    COPY --from=source /bin/busybox /sleep
    ENTRYPOINT ["/sleep", "30"]

    docker run --rm --pid="container:$SHELLLESS_C" busybox ps

Once the six TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- troubleshoot.sh reads the container's logs (empty) (TODO 1).
- It reads the exit code from docker inspect (TODO 2).
- It reads the restart counter and the final state (TODO 3).
- It verifies exit 137 together with State.OOMKilled (TODO 4).
- It distinguishes the shell's 127 from direct-exec rejection (TODO 5).
- It inspects the shellless container's processes through a shared PID namespace (TODO 6).
- run.sh prints OK 1..6 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — the container is mute: docker logs returns nothing.
- **OK 2** — docker inspect reveals the exit code (42): the diagnosis comes from there, not
  from the logs.
- **OK 3** — the crash loop is visible: the restart counter is greater than zero and the
  final state is "exited" (the policy gave up).
- **OK 4** — exit 137 and OOMKilled=true together confirm that the process was killed for
  exhausting memory.
- **OK 5** — the shell returns 127; direct exec is rejected before the process starts, with
  a different state and error.
- **OK 6** — sh cannot start in the scratch container, while the helper sees its process by
  sharing the PID namespace.

## Reflection questions

**a.** A container can be mute for many reasons: it crashed before printing, it writes to a
file instead of stdout, PID 1 does not forward its output (chapter 10), or the buffer was
not flushed. How do you diagnose when the logs do not help — and why are docker inspect and
the exit code the first foothold?

**b.** A restart policy (no, on-failure, always, unless-stopped) decides whether and how
many times a container restarts. Why is always on a container that crashes at once a
potentially infinite loop, and how does Docker's growing backoff dampen it? How do
RestartCount and the state reveal it — and what is the same phenomenon called in Kubernetes
(CrashLoopBackOff)?

**c.** Why are neither 137 nor 127 enough on their own to close the diagnosis? What
counter-evidence does docker inspect provide for an OOM, what difference separates shell
form from direct exec, and what can — and cannot — a helper sharing only the PID namespace
observe?

## Cleanup

Nothing to tear down by hand: all cap26 containers and the scratch image built by the test
are removed by the script, even on error, through a safety trap. The busybox base images
stay in cache. The daemon is never restarted.

## Where it leads

You can reconstruct a container's story even when it is silent. **Chapter 27** closes Part
7 and the manual with real day-2: maintenance — cleaning up orphaned images, containers and
volumes, managing space — and the horizons beyond the single host, the bridge toward
orchestration. For the command reference, see the volume's appendices.
