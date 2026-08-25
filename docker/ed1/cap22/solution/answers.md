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

**TODO 4 (22.2) — inject variables from an env file:** under the app service,

    env_file:
      - ./app.env

**TODO 5 (22.2) — create deterministic source collisions:** under the app service,

    environment:
      SOURCE_PRIORITY: from-environment
      SHELL_PRIORITY: ${SHELL_PRIORITY}

The .env, app.env, and db_password.txt (never committed):

    APP_ENV=production
    DOTENV_ONLY=from-dotenv
    SHELL_PRIORITY=from-dotenv
    ENV_FILE_ONLY=from-env-file
    SOURCE_PRIORITY=from-env-file
    s3cr3t-pw

DOTENV_ONLY is deliberately never referenced in compose.yaml, so it does not enter
the container. ENV_FILE_ONLY does enter through app.env. SOURCE_PRIORITY proves that
an environment entry wins over the same key in env_file. When Compose is launched as
SHELL_PRIORITY=from-shell docker compose ..., the process shell supplies the value
for ${SHELL_PRIORITY} instead of the value in .env.

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

The exercise also makes the boundary executable: an unreferenced key in .env is
absent from the container, whereas a key in the service's env_file is injected. For
the collisions demonstrated here, environment overrides env_file, and a value
exported by the process shell overrides the same interpolation value in .env.

**b. Why a secret beats an environment variable for sensitive data.**

An environment variable is remarkably leaky. It shows up in docker inspect and in the
process list, it is inherited by every child process the app spawns, it is easy to
print by accident in a stack trace or a debug log, and it sits in the container's
environment for the whole run. A secret avoids all of that: Compose mounts it as a
file under /run/secrets using a bind mount, with the effective permissions of the host
file, and it is absent from the environment entirely. So someone who inspects
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
