# Docker — exercises

Hands-on labs for the Calm ICT book "Manuale di Docker" (metaphor: the harbour
master who ships your applications). Each chapter of the book ends with a
Laboratorio box that points here: a self-contained exercise you complete and
verify. The book teaches the why; these labs make you prove it with your hands.

Every exercise has the same shape:

    ed1/capNN/
        README.it.md   - the brief (Italian)
        README.en.md   - the brief (English, mirror)
        start/         - working but incomplete files, with numbered TODOs
        solution/      - the completed, tested version
            run.sh     - end-to-end check, prints ALL CHECKS PASSED
            answers.md - the solved TODOs and the reflection answers

See SETUP.md for the environment. Most labs assume Linux with Docker Engine;
the early chapters (kernel foundations) use only standard tools such as unshare,
so they run without Docker and without root.

## Chapter index

| Chapter | Title | Level | Folder |
|---|---|---|---|
| 1 | The bare-hands container — build one with unshare, prove it is just a process | Foundational | [ed1/cap01](ed1/cap01/) |
| 2 | The six rooms — one process isolated in several namespaces at once (UTS/PID/MNT/NET/USER) | Foundational | [ed1/cap02](ed1/cap02/) |
| 3 | The ceiling and the OOM — impose a cgroup memory limit, watch the OOM killer and exit 137 | Intermediate | [ed1/cap03](ed1/cap03/) |
| 4 | The overlay by hand — mount OverlayFS and prove Copy-on-Write, two containers isolated | Intermediate | [ed1/cap04](ed1/cap04/) |
| 5 | The chain and the custodian — the socket API, and the container's parent is the shim (live-restore) | Intermediate | [ed1/cap05](ed1/cap05/) |
| 6 | The OCI recipe — build and run a container by hand with runc, the config.json is the container | Intermediate | [ed1/cap06](ed1/cap06/) |
| 7 | Dying gracefully — the PID 1 signal trap: ignore SIGTERM (exit 137) vs --init (exit 143) | Intermediate | [ed1/cap07](ed1/cap07/) |
| 8 | The manifest — an image is a config + a stack of content-addressed layers; sha256 digest and layer sharing | Intermediate | [ed1/cap08](ed1/cap08/) |
| 9 | The loading plan — the fundamental Dockerfile instructions: FROM, WORKDIR, RUN, COPY, ENV, CMD | Fundamental | [ed1/cap09](ed1/cap09/) |
| 10 | The captain and the orders — ENTRYPOINT vs CMD and the startup process; exec form makes the app PID 1 | Intermediate | [ed1/cap10](ed1/cap10/) |
| 11 | The warehouse and the light ship — build cache ordering and Multi-Stage builds; COPY --from ships only the artifact | Intermediate | [ed1/cap11](ed1/cap11/) |
| 12 | The ship in production — small, secure, non-root images: a dedicated USER, ownership, least privilege | Advanced | [ed1/cap12](ed1/cap12/) |
| 13 | What stays ashore — the lifecycle of data: the container's writable layer is ephemeral, a named volume persists | Fundamental | [ed1/cap13](ed1/cap13/) |
| 14 | Three ways to stow — bind mounts, volumes and tmpfs: host-shared vs daemon-managed vs in-memory | Intermediate | [ed1/cap14](ed1/cap14/) |
| 15 | The number on the badge — UID/GID permissions on shared volumes: match the numeric UID or the write is denied | Advanced | [ed1/cap15](ed1/cap15/) |
| 16 | The cable and the switchboard — how Docker networks a container: network namespace, veth pair, the docker0 bridge | Advanced | [ed1/cap16](ed1/cap16/) |
| 17 | The private switchboard — default vs custom bridge: a user-defined network resolves containers by name and isolates them | Advanced | [ed1/cap17](ed1/cap17/) |
| 18 | Plugged in or unplugged — the host and none drivers, and choosing: host shares the host stack, none has no network | Advanced | [ed1/cap18](ed1/cap18/) |
| 19 | On the quay, and beyond the horizon — macvlan (own MAC on the segment), ipvlan and the overlay horizon | Cloud Architect | [ed1/cap19](ed1/cap19/) |
| 20 | The fleet in one file — designing a multi-service app with Docker Compose: services, depends_on, the app network | Intermediate | [ed1/cap20](ed1/cap20/) |
| 21 | The all-clear signal — dependencies, healthchecks and startup order: wait for healthy, not just started | Advanced | [ed1/cap21](ed1/cap21/) |
| 22 | The safe, not the sticky note — configuration with env vars, .env and secrets: mount secrets as files, not env | Advanced | [ed1/cap22](ed1/cap22/) |
| 23 | King only in his own room — rootless and the privilege model: root in a user namespace maps to an unprivileged host user | Cloud Architect | [ed1/cap23](ed1/cap23/) |

More chapters are added as the volume is consolidated.
