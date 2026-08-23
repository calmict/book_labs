# Chapter 9 — The loading plan

**Level:** Foundational

In chapter 8 you took an image apart into its layers; now you build one yourself,
with intent. The Dockerfile is the ship's loading plan: an ordered list of
instructions saying which hull to start from, what to load, where to put it, and
which command to run on departure. In this lab you complete a Dockerfile with the
fundamental instructions — COPY, ENV, CMD — and check that the built image behaves
exactly as you declared it: the file in the right place, the variable set, the
default command starting on its own.

## Objectives

- Start from a base image with FROM and fix the working directory with WORKDIR
  (9.1, 9.4).
- Bring a file from the build context into the image with COPY (9.3).
- Set an environment variable with ENV, which the application reads at runtime
  (9.4).
- Declare the default command with CMD, and see it start when you run the
  container with no arguments (9.5).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 8: you know every instruction that touches the filesystem becomes a
  layer. Here you write those instructions.

## The scenario

In start/ you will find an incomplete Dockerfile and greet.sh, a small app that
prints a greeting read from an environment variable. The Dockerfile starts from
busybox, fixes WORKDIR /app and creates a file with RUN, but it does not load the
app, does not set the greeting and has no default command. You fill three gaps
(TODO 1..3) so the image is complete. Throwaway image, no privileges, the shared
daemon is not touched.

Prepare the environment:

    cd docker/ed1/cap09/start

### Phase 1 — Base, context and layers (9.1, 9.2)

The Dockerfile starts from FROM busybox (the hull), fixes WORKDIR /app (where to
work) and runs a RUN at build time. Every instruction that changes the filesystem
adds a layer: the same stack you counted in chapter 8. Note: docker build sends
the whole folder (the build context) to the daemon, not just the Dockerfile.

### Phase 2 — Loading the app with COPY (9.3 — TODO 1)

Open start/Dockerfile and complete **TODO 1**: copy greet.sh from the build
context into the image's WORKDIR.

    COPY greet.sh /app/greet.sh

### Phase 3 — The greeting as an environment variable (9.4 — TODO 2)

Complete **TODO 2**: set the GREETING variable, which greet.sh reads at runtime.
ENV writes it into the image config, so it applies to every container born from it.

    ENV GREETING=ciao

### Phase 4 — The default command with CMD (9.5 — TODO 3)

Complete **TODO 3**: declare the default command, so running the container with no
arguments starts the app. Unlike RUN (which runs at build time), CMD runs nothing
now: it is only metadata, the command that will start at runtime.

    CMD ["sh", "/app/greet.sh"]

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- The Dockerfile copies greet.sh into the WORKDIR (TODO 1).
- It sets the GREETING environment variable (TODO 2).
- It declares the default command with CMD (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh builds the image and checks, point by point:

- **OK 1** — COPY and WORKDIR: greet.sh is in the image at /app and the config's
  WorkingDir is /app.
- **OK 2** — ENV: the image config contains GREETING=ciao.
- **OK 3** — CMD: running the container with no arguments, the default command runs
  greet.sh and prints "ciao mondo", using the variable that was set.

## Reflection questions

**a.** The order of instructions is not neutral: why is it better to put what
rarely changes (the base, the dependencies) before what changes often (the app
code)? Connect the answer to the layers of chapter 8 and the build cache of
chapter 11.

**b.** RUN and CMD look similar but live at different times: RUN runs during the
build and freezes its result into a layer; CMD runs nothing at build, it is the
command that will start at runtime. Why is this difference the reason CMD creates
no layer and can be overridden on start?

**c.** docker build sends the whole build context to the daemon. What does a large
context or one with sensitive files imply, and what is a .dockerignore for? And why
is WORKDIR preferable to a "cd" inside a RUN?

## Cleanup

Nothing to tear down by hand: the test image is removed by the script (docker rmi,
plus a safety trap) at the end; the test works in its own context and leaves no
container. The busybox base image stays in cache (shared). The daemon is never
restarted.

## Where it leads

You declared a default command with CMD. **Chapter 10** opens exactly this knot:
the difference between ENTRYPOINT and CMD and the container's startup process — who
is really PID 1, and how arguments and command combine. For the full reference of
Dockerfile instructions, see the volume's appendices.
