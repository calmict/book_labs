# Chapter 9 — The loading plan

**Level:** Foundational

In chapter 8 you took an image apart into its layers; now you build one yourself,
with intent. The Dockerfile is the ship's loading plan: an ordered list of
instructions saying which hull to start from, what to load, where to put it, and
which command to run on departure. In this lab you complete a Dockerfile with the
fundamental instructions — COPY, ENV, CMD — and check that the built image behaves
exactly as you declared it. Then you weigh the same work written two ways, with
the cleanup inside or outside the same RUN, and you meet the ARG trap: a value
that lives only during the build, and stays readable in the metadata forever.

## Objectives

- Start from a base image with FROM and fix the working directory with WORKDIR
  (9.1, 9.4).
- Understand why what you create and delete in the same RUN costs nothing, while
  what you delete in a later RUN costs forever (9.2).
- Bring a file from the build context into the image with COPY (9.3).
- Tell ARG from ENV — build-time against run-time — and see that an ARG value stays
  carved into the image history (9.4).
- Set an environment variable with ENV, which the application reads at runtime
  (9.4).
- Declare the default command with CMD, and see it start when you run the
  container with no arguments (9.5).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 8: you know every instruction that touches the filesystem becomes a
  layer, and that a layer can add to the one below but never subtract from it.
  Here you write those instructions, and pay the bill when you write them badly.

## The scenario

In start/ you will find an incomplete Dockerfile and greet.sh, a small app that
prints a greeting read from an environment variable. The Dockerfile starts from
busybox, fixes WORKDIR /app and creates a file with RUN, but it does not load the
app, declares no build parameter, does not set the greeting and has no default
command. You fill five gaps (TODO 1..5) so the image is complete.

Next to it there is Dockerfile.naive, already complete: it is not an exercise, it
is the term of comparison. It does the same work as TODO 1 but in two RUNs instead
of one, and ends up eight megabytes heavier. Throwaway images, no privileges, the
shared daemon is not touched.

Prepare the environment:

    cd docker/ed1/cap09/start

### Phase 1 — Base, context and layers (9.1, 9.2)

The Dockerfile starts from FROM busybox (the hull), fixes WORKDIR /app (where to
work) and runs a RUN at build time. Every instruction that changes the filesystem
adds a layer: the same stack you counted in chapter 8. Note: docker build sends
the whole folder (the build context) to the daemon, not just the Dockerfile.

### Phase 2 — The layer that weighs nothing (9.2 — TODO 1)

Open start/Dockerfile and complete **TODO 1**: create an eight-megabyte temporary
file and delete it **in the same RUN**. The layer records the filesystem as it is
at the end of the instruction: if the file is gone, the layer is empty.

    RUN dd if=/dev/urandom of=/tmp/payload.bin bs=1M count=8 2>/dev/null && rm -f /tmp/payload.bin

Look at Dockerfile.naive: it does the same two things in two separate RUNs. There
the file is born in one layer and deleted in the next — but the layer underneath
stays as it was, and the image carries it forever. It is the rule of chapter 8
seen from the builder's side.

### Phase 3 — Loading the app with COPY (9.3 — TODO 2)

Complete **TODO 2**: copy greet.sh from the build context into the image's
WORKDIR.

    COPY greet.sh /app/greet.sh

### Phase 4 — The build parameter with ARG (9.4 — TODO 3)

Complete **TODO 3**: declare the parameter the RUN below uses to stamp the build
file. ARG lives only while you build: it will not be a variable of the container.
But the value you pass with --build-arg ends up in the image history, and from
there anyone holding the image can read it.

    ARG BUILD_TOKEN=changeme

This is why a secret is never passed through ARG.

### Phase 5 — The greeting as an environment variable (9.4 — TODO 4)

Complete **TODO 4**: set the GREETING variable, which greet.sh reads at runtime.
ENV writes it into the image config, so it applies to every container born from it
— unlike ARG, which no longer exists at runtime.

    ENV GREETING=ciao

### Phase 6 — The default command with CMD (9.5 — TODO 5)

Complete **TODO 5**: declare the default command, so running the container with no
arguments starts the app. Unlike RUN (which runs at build time), CMD runs nothing
now: it is only metadata, the command that will start at runtime.

    CMD ["sh", "/app/greet.sh"]

Once the five TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- The Dockerfile creates and deletes the temporary file in a single RUN (TODO 1).
- It copies greet.sh into the WORKDIR (TODO 2).
- It declares the ARG build parameter (TODO 3).
- It sets the GREETING environment variable (TODO 4).
- It declares the default command with CMD (TODO 5).
- run.sh prints OK 1..5 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh builds the two images and checks, point by point:

- **OK 1** — COPY and WORKDIR: greet.sh is in the image at /app and the config's
  WorkingDir is /app.
- **OK 2** — ENV: the image config contains GREETING=ciao.
- **OK 3** — CMD: running the container with no arguments, the default command runs
  greet.sh and prints "ciao mondo", using the variable that was set.
- **OK 4** — one RUN or two: in the image you built, the layer that creates and
  deletes the file weighs 0 B, while the naive image, doing the same work in two
  instructions, is eight megabytes heavier. If TODO 1 is not filled in, that layer
  does not exist and the check stops.
- **OK 5** — ARG against ENV: the value passed with --build-arg is readable in the
  image history, but inside the container it does not exist; GREETING does. The
  plaintext-secret trap and the build-time / run-time border, measured.

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

Nothing to tear down by hand: the two test images are removed by the script
(docker rmi, plus a safety trap) at the end; the test works in its own context and
leaves no container. The busybox base image stays in cache (shared). The daemon is
never restarted.

## Where it leads

You declared a default command with CMD. **Chapter 10** opens exactly this knot:
the difference between ENTRYPOINT and CMD and the container's startup process — who
is really PID 1, and how arguments and command combine. For the full reference of
Dockerfile instructions, see the volume's appendices.
