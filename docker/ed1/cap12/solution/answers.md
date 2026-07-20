# Chapter 12 — Answers

## The completed TODOs

**TODO 1 (12.2) — a dedicated non-root user:**

    RUN adduser -D appuser

**TODO 2 (12.3) — the user owns its app directory:**

    RUN chown -R appuser /app

**TODO 3 (12.2) — drop to the non-root user:**

    USER appuser

## Reflection questions

**a. Namespaces isolate the container, so why is running as root inside still a
risk?**

Namespaces limit what a process can see and touch, but they do not make root
harmless. Root inside the container still holds the full set of capabilities the
runtime grants (chapter 6), can write any file the image or a mounted volume
exposes, and is the ideal launch pad for any escape: a kernel bug, a misconfigured
capability, a host path mounted read-write. If the process is compromised, a
non-root user is boxed in — it owns only its own files, cannot touch root-owned
paths, cannot use privileged operations — whereas root can do far more before
anything stops it. The USER namespace (chapter 2) can even map container-root to an
unprivileged host user, but the simplest, most portable win is to just not be root
in the first place: run as an unprivileged user and own only what you need.

**b. Why declare USER in the image, and why is chown still needed?**

Passing --user at docker run works only if whoever runs the container remembers to;
declaring USER in the image makes non-root the default for every container, ever
where, reproducibly — the security property travels with the image instead of
depending on the run command. The chown is still needed because dropping to a
non-root user means that user must own the files it has to write. Without it, the
app directory stays owned by root, and the non-root process cannot create or modify
files there — the container would run but the app would fail on its first write.
Least privilege is exactly this pairing: be non-root, and own only your own
directory.

**c. How does a minimal base mean less attack surface?**

Every binary, shell, interpreter and package inside an image is something an
attacker can use and something that can carry a CVE you must track and patch. A
minimal base (busybox, or a distroless image with no shell or package manager at
all) removes most of that: fewer tools to abuse, fewer libraries to have
vulnerabilities, a smaller image to store and pull. Combined with the Multi-Stage
build of chapter 11 — which leaves the compilers and caches behind in the build
stage and ships only the artifact — you end up with a final image that contains
essentially your program and nothing else. Less inside is less to attack and less
to maintain.
