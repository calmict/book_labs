# Chapter 22 — Answers

## The completed TODOs

**TODO 1 (22.1) — env var from .env:** under the app service,

    environment:
      APP_ENV: ${APP_ENV}

**TODO 2 (22.3) — define the secret from a file:** at project level,

    secrets:
      db_password:
        file: ./db_password.txt

**TODO 3 (22.3) — give the secret to the service:** under the app service,

    secrets:
      - db_password

The .env and db_password.txt (never committed):

    APP_ENV=production
    s3cr3t-pw

## Reflection questions

**a. environment vs .env, and why .env is gitignored.**

environment sets variables inside the service — they exist in the running container.
.env is different: it is a file of KEY=VALUE pairs that Compose reads to resolve
${...} substitutions in the compose file (and to provide defaults), and it lives
alongside the compose but outside it. Keeping the values in .env, separate from the
compose, means the same compose file runs unchanged in dev, staging and production —
only the .env differs. And .env belongs in .gitignore because it is where real values
land, including credentials: committing it would publish them and freeze one
environment's settings into the repo. You commit an example (documented in the README
here, since book_labs even gitignores .env.*), never the real file.

**b. Why a secret beats an environment variable for sensitive data.**

An environment variable is remarkably leaky. It shows up in docker inspect and in the
process list, it is inherited by every child process the app spawns, it is easy to
print by accident in a stack trace or a debug log, and it sits in the container's
environment for the whole run. A secret avoids all of that: Compose mounts it as a
file under /run/secrets, on a tmpfs (in memory, not on disk), with restricted
permissions, and it is absent from the environment entirely. So someone who inspects
the container, reads its env, or scrapes its logs finds nothing — the value is only in
a file the app reads deliberately. Same data, far smaller exposure.

**c. File-mounted secrets and the bridge to Kubernetes.**

Compose's file-based secrets are the local, simplest form of the pattern; in
production the value would come from a secret manager — HashiCorp Vault, the cloud
provider's secret store — rather than a plaintext file on the host. But the shape is
the same everywhere: the secret is delivered to the container as a mounted file and
read from there, never baked into the image and never set as an environment variable.
Kubernetes Secrets work exactly this way — mounted as files (or, less safely, as env
vars, which the same reasoning argues against) — so the habit you build here, "mount
it, do not export it", is the habit that keeps credentials out of sight at cluster
scale too.
