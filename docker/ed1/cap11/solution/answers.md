# Chapter 11 — Answers

## The completed TODOs

**TODO 1 (11.3) — name the build stage:**

    FROM busybox AS build

**TODO 2 (11.4) — copy only the artifact into the final stage:**

    COPY --from=build /out/app /app

**TODO 3 (11.2) — dependencies before the source, for the cache:**

    COPY deps.txt ./deps.txt
    RUN cat deps.txt > /out/deps-installed.txt

## Reflection questions

**a. Why copy and install dependencies before the code?**

The cache reuses a layer only while its instruction and everything below it are
unchanged; a change invalidates that layer and every layer above, never those
below. So if you copy the dependency manifest and install dependencies first, and
copy the code last, then editing the code — which you do constantly — invalidates
only the final, cheap layers, while the expensive dependency install stays cached.
Swap the order (code first) and every code edit re-runs the whole dependency
install from scratch. In a real project a dependency install is minutes; multiplied
by every build and every CI run, ordering is the difference between a fast loop and
a slow one. In the lab, changing app.txt leaves the deps-installed step CACHED
precisely because it sits below the source copy.

**b. Why is the Multi-Stage final image smaller and safer?**

A single-stage image keeps everything the build needed: compilers, headers, package
manager caches, intermediate files — all shipped to production, all extra weight and
extra attack surface. A Multi-Stage build does the messy assembly in a build stage
and then, in a clean final stage, copies only the finished artifact with
COPY --from. What is NOT shipped: the toolchain, the sources, the dependency
caches. Because images are content-addressed stacks of layers (chapter 8), the
final image is just the minimal base plus the one artifact layer — fewer bytes to
store and pull, and far less inside for an attacker to use. In the lab the final
image has /app and nothing from the build stage: deps.txt and deps-installed.txt
never leave the warehouse.

**c. How does COPY --from separate build from runtime?**

COPY --from=<stage> pulls a path out of another stage (or even an external image,
COPY --from=someimage:tag). This lets one Dockerfile describe two different worlds:
the build stage says how the artifact is produced, with all the tools; the final
stage says what actually runs, with none of them. The boundary between them is a
single, explicit copy of the artifact — so "how it is built" and "what runs in
production" stop being the same image. That separation is exactly the ground
chapter 12 builds on: a production image that starts from a minimal base, adds only
the artifact, and runs it as an unprivileged user.
