# Chapter 10 — The captain and the orders

**Level:** Intermediate

You gave a default command with CMD; but who really commands at departure? A
container has a single process in the place of honour — the PID 1 you met in
chapter 7 — and two instructions decide who it is and what it runs: ENTRYPOINT and
CMD. The metaphor is the captain and the orders: ENTRYPOINT is the ship's fixed
captain, CMD are the default orders, which can be changed at departure. In this lab
you combine them, see how arguments passed to docker run override CMD but not
ENTRYPOINT, and then time the shutdown of the same script started three different
ways: the difference between stopping in one second and being killed when time
runs out is measurable, and it is not where you expect it.

## Objectives

- Tell ENTRYPOINT (the fixed executable) from CMD (the default arguments) and see
  them combined (10.2, 10.3, 10.5).
- Observe that arguments passed to docker run override CMD but leave ENTRYPOINT
  untouched (10.5).
- Understand exec form versus shell form: exec makes your process PID 1 (10.1,
  10.4).
- Reconnect PID 1 to the signals of chapter 7: whoever is PID 1 receives SIGTERM
  — and whoever does not handle it is killed when the grace period expires.
- Measure the exact condition behind the slowdown: it is not the shell form in
  itself, it is the shell that stays in the way (10.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 7 (PID 1 and signals) and chapter 9 (COPY, CMD): here you put them
  together.

## The scenario

In start/ you will find an incomplete Dockerfile and entry.sh, a script that prints
its own PID and the arguments it received, and that with the argument "serve" stays
alive handling SIGTERM. The Dockerfile starts from busybox but does not load the
script, does not name the captain and gives no default orders. You fill three gaps
(TODO 1..3).

Next to them there are two ready-made Dockerfiles — Dockerfile.shell-stays and
Dockerfile.shell-alone: they are not exercises, they are the terms of comparison
for phase 5. Throwaway images, no privileges, the shared daemon is not touched.

Prepare the environment:

    cd docker/ed1/cap10/start

### Phase 1 — The startup process: who is PID 1 (10.1, 10.4)

A container runs a process as PID 1. How you write ENTRYPOINT/CMD decides who it
is: the **exec form** (a JSON array, like ["/entry.sh"]) runs your program
directly, and it becomes PID 1; the **shell form** (a string) wraps it in
/bin/sh -c. Whether the shell then really keeps the place of honour depends on what
you asked it to do: you will check that yourself in phase 5.

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

### Phase 5 — Three departures, three shutdowns (10.4)

Nothing to write here: look at the two ready-made Dockerfiles and understand what
changes. They are the same script, started three ways.

- Your image, exec form: ENTRYPOINT ["/entry.sh"] with the argument "serve".
- Dockerfile.shell-stays, shell form with something after the script:

      CMD /entry.sh serve; echo stopped

- Dockerfile.shell-alone, shell form with the script alone:

      CMD /entry.sh serve

The test starts the three containers and stops them with docker stop, shortening to
five seconds the grace period that defaults to ten (chapter 7), so you are not kept
waiting. Then it times them, reads the exit code and asks the script which PID it
was given. The result says more than the rule you have in mind: only one of the
three containers dies of SIGKILL, and it is not the one you would have picked by
looking at the form of the CMD alone.

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- The Dockerfile copies entry.sh into the image (TODO 1).
- It declares ENTRYPOINT in exec form (TODO 2).
- It gives default arguments with CMD (TODO 3).
- run.sh prints OK 1..5 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh builds the three images and checks, point by point:

- **OK 1** — ENTRYPOINT plus CMD: running with no arguments, ENTRYPOINT runs with
  the default arguments from CMD (args = default).
- **OK 2** — docker run arguments override CMD but not ENTRYPOINT: running with
  "foo bar", args = foo bar and the captain is still entry.sh.
- **OK 3** — exec form: the script is PID 1 (self_pid = 1), so it receives signals
  first-hand (chapter 7), with no shell wrapping it.
- **OK 4** — the shutdown times compared: in exec form the script is PID 1, receives
  SIGTERM and the container stops in about a second with code 0; with the shell
  still in the way the script is no longer PID 1, the signal stops at the shell,
  the grace period expires and the container is killed, with code 137.
- **OK 5** — the condition behind the rule: if all you ask the shell to do is run
  the script, busybox's shell replaces itself with it instead of waiting for it.
  PID 1 is the script again, and the shutdown is prompt once more. What costs is
  not the shell form: it is the shell that stays.

## Reflection questions

**a.** ENTRYPOINT and CMD are not two alternative commands: how do they combine
when both are present, and what exactly happens when you run docker run image
argument? Why is CMD alone overridden entirely, while with ENTRYPOINT it becomes
only the list of default arguments?

**b.** In phase 5 two containers out of three stop at once, and the two using the
shell form behave in opposite ways. What really tells the slow case apart — the form
you wrote the CMD in, or something else? And why does a PID 1 that does not handle
SIGTERM survive it, while the same process with any other PID would die? Connect
the answer to chapter 7.

**c.** When is CMD alone, ENTRYPOINT alone, or both the right choice? Think of an
"executable" image (a tool that always takes arguments) versus a generic image, and
what --entrypoint is for when you need to override the captain at startup.

## Cleanup

Nothing to tear down by hand: the three test images are removed by the script
(docker rmi, plus a safety trap) at the end, and every container started for the
timing is stopped and removed right after the measurement. The busybox base image
stays in cache (shared). The daemon is never restarted.

## Where it leads

You know who commands a container and how. **Part 3** closes by looking at speed
and size: **chapter 11** goes into the strategic cache and Multi-Stage Builds — how
to order and split the layers of chapter 8 so builds are fast and images are light.
For the instruction reference, see the volume's appendices.
