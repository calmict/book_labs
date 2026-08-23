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
- Compare the weight produced by separate RUN instructions with a concatenated
  RUN that removes the data in the same layer (9.2).
- Verify that ARG is build-time data, does not reach the runtime environment,
  but its build value remains readable in history (9.4).

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
(TODO 1..3) so the image is complete. Two dedicated Dockerfiles then extend the
lab with TODO 4 and TODO 5: RUN layer weight and the boundary between ARG and
ENV. Throwaway images, no privileges, the shared daemon is not touched.

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

### Phase 5 — Cleanup and RUN layer weight (9.2 — TODO 4)

Open start/Dockerfile.layers. In the first stage, create an 8 MiB file with dd in
one RUN and delete it in a later RUN. In the second stage, starting again from the
same base image, create and delete the same file in one concatenated RUN. A later
deletion hides the file but does not remove it from the layer that introduced it;
within the same layer, the file does not enter the result.

### Phase 6 — ARG in history (9.4 — TODO 5)

Open start/Dockerfile.arg. Declare ARG SECRET_TOKEN and use it in a RUN, without
turning it into ENV. The test passes a value with --build-arg, searches for it
with docker history --no-trunc, and verifies that docker run with env does not
expose SECRET_TOKEN. Compare this with GREETING, which remains available at
runtime because it is an ENV.

Once all five TODOs are filled, run the test from the completed copy:

    cd ../solution
    ./run.sh

## "Done" criteria

- The Dockerfile copies greet.sh into the WORKDIR (TODO 1).
- It sets the GREETING environment variable (TODO 2).
- It declares the default command with CMD (TODO 3).
- The two RUN variants produce images with a measurable size difference (TODO 4).
- The ARG value is readable in history but not in the runtime environment, while
  GREETING set with ENV is present (TODO 5).
- run.sh prints OK 1..5 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh builds the image and checks, point by point:

- **OK 1** — COPY and WORKDIR: greet.sh is in the image at /app and the config's
  WorkingDir is /app.
- **OK 2** — ENV: the image config contains GREETING=ciao.
- **OK 3** — CMD: running the container with no arguments, the default command runs
  greet.sh and prints "ciao mondo", using the variable that was set.
- **OK 4** — RUN and layers: compares the images with separate and concatenated
  cleanup using docker image inspect; the difference must be at least 75% of the
  8 MiB file.
- **OK 5** — ARG and ENV: docker history --no-trunc exposes the value passed with
  --build-arg, SECRET_TOKEN is absent from the runtime environment, and GREETING
  is present.

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

Nothing to tear down by hand: the test images are removed by the script (docker
rmi, plus a safety trap) at the end; the test uses unique PID-based tags, works in
its own context and leaves no container. The busybox base image stays in cache
(shared). The daemon is never restarted.

## Where it leads

You declared a default command with CMD. **Chapter 10** opens exactly this knot:
the difference between ENTRYPOINT and CMD and the container's startup process — who
is really PID 1, and how arguments and command combine. For the full reference of
Dockerfile instructions, see the volume's appendices.
