# Chapter 10 — The captain and the orders

**Level:** Intermediate

You gave a default command with CMD; but who really commands at departure? A
container has a single process in the place of honour — the PID 1 you met in
chapter 7 — and two instructions decide who it is and what it runs: ENTRYPOINT and
CMD. The metaphor is the captain and the orders: ENTRYPOINT is the ship's fixed
captain, CMD are the default orders, which can be changed at departure. In this lab
you combine them, see how arguments passed to docker run override CMD but not
ENTRYPOINT, and check that the exact form you write them in decides whether your
process is PID 1 or ends up wrapped in a shell.

## Objectives

- Tell ENTRYPOINT (the fixed executable) from CMD (the default arguments) and see
  them combined (10.2, 10.3, 10.5).
- Observe that arguments passed to docker run override CMD but leave ENTRYPOINT
  untouched (10.5).
- Understand exec form versus shell form: exec makes your process PID 1 (10.1,
  10.4).
- Reconnect PID 1 to the signals of chapter 7: whoever is PID 1 receives SIGTERM.

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 7 (PID 1 and signals) and chapter 9 (COPY, CMD): here you put them
  together.

## The scenario

In start/ you will find an incomplete Dockerfile and entry.sh, a script that prints
its own PID and the arguments it received. The Dockerfile starts from busybox but
does not load the script, does not name the captain and gives no default orders.
You fill three gaps (TODO 1..3). Throwaway image, no privileges, the shared daemon
is not touched.

Prepare the environment:

    cd docker/ed1/cap10/start

### Phase 1 — The startup process: who is PID 1 (10.1, 10.4)

A container runs a process as PID 1. How you write ENTRYPOINT/CMD decides who it
is: the **exec form** (a JSON array, like ["/entry.sh"]) runs your program
directly, and it becomes PID 1; the **shell form** (a string) wraps it in
/bin/sh -c, and then it is the shell that is PID 1 — with the consequences on
signals seen in chapter 7.

### Phase 2 — Loading the script (10.3 — TODO 1)

Open start/Dockerfile and complete **TODO 1**: copy entry.sh into the image. In the
context it is already executable, and COPY preserves its permissions.

    COPY entry.sh /entry.sh

### Phase 3 — The fixed captain: ENTRYPOINT (10.3 — TODO 2)

Complete **TODO 2**: declare ENTRYPOINT in exec form, so the script is the fixed
process at startup — and it is PID 1.

    ENTRYPOINT ["/entry.sh"]

### Phase 4 — The default orders: CMD (10.5 — TODO 3)

Complete **TODO 3**: give ENTRYPOINT default arguments with CMD. It is not a second
command: it is the argument list that will be passed to ENTRYPOINT, and that docker
run can override.

    CMD ["default"]

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- The Dockerfile copies entry.sh into the image (TODO 1).
- It declares ENTRYPOINT in exec form (TODO 2).
- It gives default arguments with CMD (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh builds the image and checks, point by point:

- **OK 1** — ENTRYPOINT plus CMD: running with no arguments, ENTRYPOINT runs with
  the default arguments from CMD (args = default).
- **OK 2** — docker run arguments override CMD but not ENTRYPOINT: running with
  "foo bar", args = foo bar and the captain is still entry.sh.
- **OK 3** — exec form: the script is PID 1 (self_pid = 1), so it receives signals
  first-hand (chapter 7), with no shell wrapping it.

## Reflection questions

**a.** ENTRYPOINT and CMD are not two alternative commands: how do they combine
when both are present, and what exactly happens when you run docker run image
argument? Why is CMD alone overridden entirely, while with ENTRYPOINT it becomes
only the list of default arguments?

**b.** The exec form (JSON array) and the shell form (string) look equivalent but
are not: why does exec make your process PID 1, while shell wraps it in sh -c which
becomes PID 1? Connect the answer to chapter 7: why can the shell form make a
container "take ten seconds" to stop?

**c.** When is CMD alone, ENTRYPOINT alone, or both the right choice? Think of an
"executable" image (a tool that always takes arguments) versus a generic image, and
what --entrypoint is for when you need to override the captain at startup.

## Cleanup

Nothing to tear down by hand: the test image is removed by the script (docker rmi,
plus a safety trap) at the end; the test leaves no container. The busybox base
image stays in cache (shared). The daemon is never restarted.

## Where it leads

You know who commands a container and how. **Part 3** closes by looking at speed
and size: **chapter 11** goes into the strategic cache and Multi-Stage Builds — how
to order and split the layers of chapter 8 so builds are fast and images are light.
For the instruction reference, see the volume's appendices.
