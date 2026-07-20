# Chapter 9 — Answers

## The completed TODOs

**TODO 1 (9.3) — load the app from the build context:**

    COPY greet.sh /app/greet.sh

**TODO 2 (9.4) — the greeting as an environment variable:**

    ENV GREETING=ciao

**TODO 3 (9.5) — the default command run at startup:**

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
