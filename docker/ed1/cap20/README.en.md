# Chapter 20 — The fleet in one file

**Level:** Intermediate

So far you commanded one ship at a time: docker run, docker network, docker volume,
one piece at a time. But a real application is a fleet — a web, a database, a cache —
and coordinating it by hand, command after command, is fragile and unrepeatable. Part
6 introduces the tool that describes the whole fleet in a single file: Docker Compose.
In one file you declare the services, and Compose does the rest — it creates for you an
application network where services find each other by name (like the custom bridge of
chapter 17, but without writing it), respects dependencies, and starts or stops
everything with one command. In this lab you design a two-service app and verify that
they talk by name and start in the right order.

## Objectives

- Describe a multi-service application in a single Compose file (20.1).
- Define two services with an image and a command (20.2).
- Declare a dependency between services with depends_on (20.3).
- See that Compose gives the services an app network where they resolve by name
  (20.4).

## Prerequisites

- A Linux with Docker Engine running and the Docker Compose plugin (see SETUP.md).
  Your user must be able to use Docker.
- Chapter 17 (custom network, name resolution): Compose creates it for you. Chapters
  13-14 (volumes): you will compose those in the next chapters.

## The scenario

In start/ you will find compose.yaml: it describes two services, db and web, but with
no command to keep them alive and no dependency — so the app does not stay up. You fill
three gaps (TODO 1..3). The Compose project has a unique name and is removed at the end
(down); the daemon is not touched nor restarted.

Prepare the environment:

    cd docker/ed1/cap20/start

### Phase 1 — Keeping the services alive (20.2 — TODO 1, TODO 2)

Open start/compose.yaml. A service with only an image runs the default command (for
busybox, a shell that exits at once): the container does not stay up. Complete **TODO
1** and **TODO 2**: give db and web a command that keeps them alive.

    command: sleep 3600

### Phase 2 — The startup order (20.3 — TODO 3)

Complete **TODO 3**: make web start after db, by declaring the dependency. Compose will
start db first.

    depends_on:
      - db

### Phase 3 — The app network (20.4)

There is nothing to write: Compose automatically creates a network for the project and
puts both services on it. There the embedded DNS resolves the service names, so web
reaches db simply as "db" — never by IP.

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- compose.yaml defines db and web with a command that keeps them alive (TODO 1, 2).
- It declares that web depends on db (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh brings the application up and checks, point by point:

- **OK 1** — both services (db and web) are running after docker compose up.
- **OK 2** — web reaches db by service name: the app network Compose created has the
  embedded DNS.
- **OK 3** — the file declares that web depends on db (the dependency graph), from a
  single declarative file.

## Reflection questions

**a.** Compose automatically creates a network for the project and attaches all the
services to it, with the name resolution seen in chapter 17. Why in a Compose file do
you never use IP addresses, but always the service names? What would happen if two
different Compose projects each had a service called "db"?

**b.** depends_on orders startup — db before web — but by default it only waits for
db's container to have started, not for the database inside to be ready to accept
connections. Why does this distinction matter, and what is needed to wait for real
readiness (the preview of chapter 21: healthchecks)?

**c.** One file describes the whole application, and one command starts or stops it.
Why is this declarative model — "here is how it should be", not "run these commands in
this order" — the conceptual bridge toward Kubernetes, where you declare the desired
state and the orchestrator realises it?

## Cleanup

Nothing to tear down by hand: run.sh closes the project with docker compose down
(removing the project's containers and app network), with a safety trap. The busybox
base image stays in cache. The daemon is never restarted.

## Where it leads

You described an application in one file and started it with one command. But
"started" is not "ready": **chapter 21** tackles real dependencies — depends_on with a
condition, the healthchecks that say when a service is truly ready, and the startup
order that follows. For the Compose reference, see the volume's appendices.
