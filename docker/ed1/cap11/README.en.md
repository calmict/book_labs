# Chapter 11 — The warehouse and the light ship

**Level:** Intermediate

You can build an image; now you learn to build it **fast** and ship it **light**.
Two techniques make the difference, and both are about order. The first is the
cache: Docker reuses a layer as long as the instruction that produces it and
everything below are unchanged — so the order of instructions decides how much work
you redo on every build. The second is the Multi-Stage build: you use one stage as
a warehouse where you assemble with all the tools, then load onto the final ship —
a light one — only the finished goods. In this lab you combine them: put what
rarely changes before what changes often, and ship only the artifact.

## Objectives

- Understand how the cache reuses layers and why instruction order matters (11.1,
  11.2).
- Use a Multi-Stage build: a named build stage and a final stage (11.3).
- Copy from the build stage only the artifact, with COPY --from (11.4).
- Get a light final image, free of the build tools (11.5).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 8 (layers) and chapter 9 (COPY, instruction order): here you use them to
  optimise.

## The scenario

In start/ you will find an incomplete Dockerfile, deps.txt (the "dependencies") and
app.txt (the "source"). The Dockerfile should assemble in a build stage and ship
only the artifact in a light final stage, in the right order for the cache — but the
stage is not named, the artifact is not copied and the dependencies are not placed
before the source. You fill three gaps (TODO 1..3). Throwaway images, no
privileges, the shared daemon is not touched.

Prepare the environment:

    cd docker/ed1/cap11/start

### Phase 1 — How the cache works (11.1, 11.2)

Every instruction is a layer (chapter 8); Docker reuses the cached layer if that
instruction and all those below are unchanged. Change one and you invalidate its
layer and every layer above it, but not the ones below. Hence the rule: what rarely
changes (the dependencies) goes before what changes often (your code), so editing
the code does not redo the dependency install.

### Phase 2 — Naming the warehouse (11.3 — TODO 1)

Open start/Dockerfile and complete **TODO 1**: give the build stage a name, so the
final stage can pull its artifact.

    FROM busybox AS build

### Phase 3 — Loading only the finished goods (11.4 — TODO 2)

Complete **TODO 2**: in the final stage, copy from the build stage **only** the
artifact — not the tools, not the dependencies.

    COPY --from=build /out/app /app

### Phase 4 — Ordering for the cache (11.2 — TODO 3)

Complete **TODO 3**: copy and "install" the dependencies **before** copying the
source, so that when you change only the source the expensive step stays cached.

    COPY deps.txt ./deps.txt
    RUN cat deps.txt > /out/deps-installed.txt

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- The build stage is named with AS (TODO 1).
- The final stage copies only the artifact with COPY --from (TODO 2).
- The dependencies are copied and "installed" before the source (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh builds the image and checks, point by point:

- **OK 1** — the final image contains the artifact: running it prints the content
  built from the source.
- **OK 2** — Multi-Stage isolation: the final image does NOT contain the build
  stage's files (deps.txt, the dependency artifact): it is light and clean.
- **OK 3** — strategic cache: changing only the source and rebuilding, the
  dependency-install step stays CACHED, while the source is rebuilt.

## Reflection questions

**a.** The cache invalidates a layer and everything above it, never below. Why then
is it better to copy the dependency file and install it first, and only then copy
the code? What happens to the cache if you swap the order, and why does this turn
into minutes saved on every build in a real project?

**b.** In a Multi-Stage build the build stage holds compilers, headers, package
caches; the final stage copies only the artifact. Why is the final image smaller
and safer, and what is NOT shipped compared with an image built in a single stage?
How does this connect to the content-addressed layers of chapter 8?

**c.** COPY --from can pull from a named stage but also from an external image. How
does Multi-Stage separate "how it is built" from "what runs in production", and why
is this a bridge to the production images of chapter 12?

## Cleanup

Nothing to tear down by hand: the test images are removed by the script (docker
rmi, plus a safety trap) at the end; the test works in a temporary directory it
cleans up itself. The busybox base image stays in cache (shared). No persistent
container, the daemon is never restarted.

## Where it leads

You made the build fast and the image light. **Chapter 12** closes Part 3 by
taking the idea all the way: production images that are small, root-free and with
the minimum attack surface — an unprivileged user, a minimal base, no tools too
many. For the instruction reference, see the volume's appendices.
