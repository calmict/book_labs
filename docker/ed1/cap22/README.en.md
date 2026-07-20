# Chapter 22 — The safe, not the sticky note

**Level:** Advanced

An application is not only services and networks: it is also configuration. The
database address, the log level, the API key — and, among these, things that must not
end up in the clear anywhere. Docker Compose offers three tools that are easy to
confuse. Environment variables configure the service's behaviour. The .env file keeps
the values out of the compose and out of the repository. And secrets are the safe:
sensitive data mounted into the container as restricted-permission files, not written
into the environment where anyone inspecting the container would see them. In this lab
you configure a service with a variable taken from .env and give it a password as a
secret — and verify that the secret is in the right file and does not leak into the
environment.

## Objectives

- Pass an environment variable to a service (22.1).
- Take its value from a .env file, kept out of the repository (22.2).
- Give sensitive data as a secret, mounted as a file in /run/secrets (22.3).
- See why a secret does not end up in the environment, unlike an env var (22.4).

## Prerequisites

- A Linux with Docker Engine running and the Docker Compose plugin (see SETUP.md).
  Your user must be able to use Docker.
- Chapters 20-21 (Compose): here you add configuration and secrets.

## The scenario

In start/ you will find compose.yaml: the app service has no configuration and no
secret. You fill three gaps (TODO 1..3). You need two files that are **not committed**
(that is the point of the chapter): create them before testing your solution —

    cd docker/ed1/cap22/start
    printf 'APP_ENV=production\n' > .env
    printf 's3cr3t-pw' > db_password.txt

The Compose project has a unique name and is removed at the end; the daemon is not
touched. (solution/run.sh generates these two files itself in a temporary directory,
so the test depends on nothing committed.)

### Phase 1 — The variable from .env (22.1, 22.2 — TODO 1)

Open start/compose.yaml and complete **TODO 1**: give app an environment variable
whose value is taken from the .env file. Compose substitutes ${APP_ENV} with what it
finds in .env — which stays out of the repository.

    environment:
      APP_ENV: ${APP_ENV}

### Phase 2 — Defining the secret (22.3 — TODO 2)

Complete **TODO 2**: define a secret at project level, from a file. It is the safe:
the value lives in a file, not in the compose.

    secrets:
      db_password:
        file: ./db_password.txt

### Phase 3 — Giving the secret to the service (22.3 — TODO 3)

Complete **TODO 3**: assign the secret to the service. Compose mounts it inside the
container as a file at /run/secrets/db_password — not as an environment variable.

    secrets:
      - db_password

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- app receives APP_ENV with a value taken from .env (TODO 1).
- The secret db_password is defined from a file (TODO 2) and assigned to app (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh brings the application up and checks, point by point:

- **OK 1** — the environment variable APP_ENV in the container has the value taken
  from .env (production).
- **OK 2** — the secret is mounted as a file at /run/secrets/db_password and contains
  the expected value.
- **OK 3** — the secret does NOT leak into the environment: its value does not appear
  among the container's environment variables.

## Reflection questions

**a.** environment and .env look like the same thing but are not: environment puts the
variables into the service, .env provides the values for ${...} substitution and stays
out of the compose. Why does the .env file belong in .gitignore, and why is keeping
values separate from the configuration file useful even for non-secret values
(different environments, same app)?

**b.** Why is a secret better than an environment variable for sensitive data? Think
about where an env var ends up — visible in docker inspect, in docker ps, inherited by
child processes, often printed in logs — versus a secret, mounted as a
restricted-permission file in /run/secrets (on a tmpfs, not on disk) and absent from
the environment. What changes for someone who manages to inspect the container?

**c.** Compose secrets are file-based, a first step. In production the values come from
a secret manager (Vault, the cloud's secrets) instead of a file on disk. How is the
idea — mount the secret as a file, never put it in the environment — the same as
Kubernetes Secrets, and why is this model safer than pasting the key into a variable?

## Cleanup

Nothing to tear down by hand: run.sh closes the project with docker compose down and
removes the temporary directory (with the generated .env and secret file), through a
trap. If you created .env and db_password.txt in start/ to test your own solution,
remember to delete them. The busybox base image stays in cache. The daemon is never
restarted.

## Where it leads

With this chapter Part 6 is complete: you can design, order and configure a
multi-service application. **Part 7** changes theme — day-2, security, hardening.
**Chapter 23** opens with the privilege model and rootless mode: running the whole
engine without root, picking up the USER namespace of chapter 2. For the Compose
reference, see the volume's appendices.
