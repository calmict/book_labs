# Chapter 26 — The black box of the mute container

**Level:** Cloud Architect

Sooner or later comes the container that will not start, says nothing, and maybe keeps
restarting on its own. The logs are empty — mute — and the instinct is to give up. But a
container is never truly mute: even when it writes not a line, it leaves a black box.
docker inspect tells how it died — the exit code, which as you saw in chapter 7 is already
a diagnosis — and how many times it restarted before giving up, the mark of a crash loop.
In this lab you take a container that crashes in silence, with a restart policy that keeps
restarting it, and reconstruct its story without a single log line: from the exit code and
the restart counter.

## Objectives

- Recognise a "mute" container: the logs are empty, there is nothing to read there (26.1).
- Read the black box with docker inspect: the exit code, the real diagnosis (26.2, 26.4).
- Recognise the crash loop from the restart counter and the final state (26.3).
- Connect the exit code to its causes (chapter 7): 42, 137, 143, 127... (26.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use Docker.
- Chapter 7 (lifecycle and exit codes) and 25 (logs and metrics): here you use them when
  something goes wrong.

## The scenario

In start/ you will find idiag.sh: a script that starts a container which exits silently
with a non-zero code and a restart policy, and should read its logs, exit code and
restarts — but the three reads are missing. You fill three gaps (TODO 1..3). Throwaway
container (rm), the daemon is not touched.

Prepare the environment:

    cd docker/ed1/cap26/start

### Phase 1 — The silence: empty logs (26.1 — TODO 1)

Open start/idiag.sh and complete **TODO 1**: read the container's logs. They are empty: the
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

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- idiag.sh reads the container's logs (empty) (TODO 1).
- It reads the exit code from docker inspect (TODO 2).
- It reads the restart counter and the final state (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — the container is mute: docker logs returns nothing.
- **OK 2** — docker inspect reveals the exit code (42): the diagnosis comes from there, not
  from the logs.
- **OK 3** — the crash loop is visible: the restart counter is greater than zero and the
  final state is "exited" (the policy gave up).

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

**c.** The exit code is a diagnosis (chapter 7): 42 is an application error, 137 is SIGKILL
(often the OOM killer), 143 is SIGTERM, 127 "command not found", 126 "not executable". Why
is reading the exit code always the first step of troubleshooting, before even the logs?

## Cleanup

Nothing to tear down by hand: the container is removed by the script (docker rm -f, plus a
safety trap). The busybox base image stays in cache. The daemon is never restarted.

## Where it leads

You can reconstruct a container's story even when it is silent. **Chapter 27** closes Part
7 and the manual with real day-2: maintenance — cleaning up orphaned images, containers and
volumes, managing space — and the horizons beyond the single host, the bridge toward
orchestration. For the command reference, see the volume's appendices.
