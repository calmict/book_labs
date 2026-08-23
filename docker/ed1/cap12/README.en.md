# Chapter 12 — The ship in production

**Level:** Advanced

An image that works on your machine is not yet an image to put to sea. Part 3
closes by taking the idea all the way: in production the ship must be light and
well guarded — only the crew you need, no keys too many. The key too many, almost
always, is root: by default a container runs as root, and a compromised process
that is root inside the container is far more dangerous than one that is not. In
this lab you build a production image that runs as an unprivileged user, owning only
what it needs — and you verify, permission in hand, that it cannot write where it
must not.

## Objectives

- Create a dedicated non-root user and run the app as it (12.2).
- Give the user ownership of only the app directory: least privilege (12.3).
- Declare the user in the image with USER, so it applies to every container (12.2).
- See the difference in risk between root and non-root inside the container (12.1).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 2 (namespaces, including the USER namespace) and chapter 11 (Multi-Stage
  and light images): here you add security at runtime.

## The scenario

In start/ you will find an incomplete Dockerfile and app.txt. The Dockerfile builds
an image with a static application in a final `scratch` stage, but it does not drop
privileges or declare a health check. You fill two gaps (TODO 1..2) to make it
production-grade. Throwaway image, no privileges on the host, the shared daemon is
not touched.

Prepare the environment:

    cd docker/ed1/cap12/start

### Phase 1 — Why not root (12.1)

By default a container's process is root (uid 0). Namespaces (chapter 2) isolate
it, but root in the container is still the starting point for too much trouble: an
exploited bug, one capability too many, a badly mounted volume, and root inside
becomes a problem outside. The production rule is simple: run as an unprivileged
user, and own only what you need.

### Phase 2 — A dedicated user (12.2 — TODO 1)

Open start/Dockerfile and complete **TODO 1**: create a non-root user that will run
the app.

    USER appuser

### Phase 3 — Minimal ownership (12.3)

The build stage creates `appuser`; `COPY --chown` gives that user ownership of the
app directory, so it can write there and only there.

    COPY --from=build --chown=10001:10001 /app/app.txt /app/app.txt

### Phase 4 — Minimal image and health (12.4 — TODO 2)

The final `scratch` stage contains neither a shell nor a package manager. Complete
**TODO 2** by declaring the application's real probe, which Docker takes to
`healthy`.

    HEALTHCHECK --interval=1s --timeout=1s --retries=5 CMD ["/appbin", "health"]

Once the two TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- The Dockerfile declares USER to run non-root (TODO 1).
- It declares a real HEALTHCHECK (TODO 2).
- The final stage contains neither a shell nor a package manager.
- run.sh prints OK 1..5 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh builds the image and checks, point by point:

- **OK 1** — the container runs as non-root: the uid inside is not 0.
- **OK 2** — the user is declared in the image: the config reports USER=appuser, so
  it applies to every container without passing it at runtime.
- **OK 3** — least privilege: the user can write in its own /app, but is denied when
  it tries to write in /, owned by root.
- **OK 4** — the declared health check reaches `healthy`.
- **OK 5** — no shell or common package manager is executable in the final
  `scratch` stage.

## Reflection questions

**a.** Namespaces isolate the container (chapter 2), yet running as root inside is
still a risk: why? What changes, if the process is compromised, between a root user
and an unprivileged one — and how does it combine with capabilities and mounted
volumes?

**b.** USER writes the user into the image config, instead of leaving it to docker
run's --user. Why is declaring it in the image safer and more reproducible? And why
is the chown still needed: what would happen to the app if the user did not own its
directory?

**c.** A production image starts from a minimal base (busybox, or a distroless one)
and, with the Multi-Stage of chapter 11, ships only the artifact. How does "less
inside" (fewer binaries, fewer shells, fewer packages) mean less attack surface and
fewer CVEs to chase?

## Cleanup

Nothing to tear down by hand: the test image is removed by the script (docker rmi,
plus a safety trap) at the end; the test leaves no container. The busybox base image
stays in cache (shared). The daemon is never restarted.

## Where it leads

With this chapter Part 3 is complete: you can build images that are light, fast and
secure. **Part 4** changes the question: if the container is ephemeral, where do the
**data** live? **Chapter 13** opens the lifecycle of state — what survives a
container and what does not — before moving into volumes and bind mounts. For the
instruction reference, see the volume's appendices.
