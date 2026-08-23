# Chapter 9 — Answers

## The completed TODOs

**TODO 1 (9.2) — create and delete inside a single RUN, so the layer stays empty:**

    RUN dd if=/dev/urandom of=/tmp/payload.bin bs=1M count=8 2>/dev/null && rm -f /tmp/payload.bin

Dockerfile.naive does the same work in two instructions. There the payload is
written into one layer and removed in the next, and since a layer can only add to
the one below, the eight megabytes stay in the image forever: the file is invisible
in the container, and fully paid for on disk and on every pull. Written as one RUN,
the layer that produced and removed it weighs 0 B.

**TODO 2 (9.3) — load the app from the build context:**

    COPY greet.sh /app/greet.sh

**TODO 3 (9.4) — the build-time parameter stamped into the build file:**

    ARG BUILD_TOKEN=changeme

Passed at build with --build-arg. It is not an environment variable of the
container: run env inside the container and it is not there. But docker history
shows it twice — in the ARG instruction and in the RUN that used it — so a secret
passed this way is readable by anyone who has the image, and no later instruction
can take it back. Build secrets have a dedicated BuildKit mechanism instead
(chapter 11).

**TODO 4 (9.4) — the greeting as an environment variable:**

    ENV GREETING=ciao

**TODO 5 (9.5) — the default command run at startup:**

    CMD ["sh", "/app/greet.sh"]

## Reflection questions

**a. Why order rarely-changing instructions before often-changing ones?**

Each instruction becomes a layer (chapter 8), and the build cache reuses a layer
only if that instruction and everything below it are unchanged. Change something
early and every layer above it is rebuilt. So the base image and the dependencies
— which change rarely — go first, and the application code — which changes on every
commit — goes last: then editing your code invalidates only the final, cheap
layers, while the expensive dependency layers stay cached. Ordering is a cache
decision, made concrete in chapter 11 (there COPY of dependency manifests precedes
COPY of the source, exactly for this reason).

**b. Why does RUN create a layer but CMD does not?**

RUN executes a command *during the build*: its effect on the filesystem is
captured as a new layer, frozen into the image. CMD executes nothing at build
time — it only records, in the image config, the command that the container should
start with at runtime. Because it changes no filesystem state at build, there is
nothing to snapshot, so it is metadata, not a layer. That same nature is why CMD
is overridable: passing a command to docker run (or an argument) replaces or
extends it, since it was never baked into a layer — only written as the default in
the config.

**c. What does the build context imply, and what is .dockerignore for?**

docker build tars up the whole directory you point it at (the build context) and
ships it to the daemon before building. A large context — a node_modules, a .git,
build artifacts — makes every build slower and can accidentally COPY things you did
not mean to, including secrets. A .dockerignore file excludes paths from the
context (like .gitignore), keeping builds fast and images clean, and preventing
sensitive files from being copied in. WORKDIR is preferable to a "cd" inside a RUN
because cd only affects that single RUN's shell and is lost afterwards, while
WORKDIR sets the directory for every following instruction *and* for the container
at runtime — and it is recorded in the config, so it is visible and reproducible
rather than hidden inside a shell step.
