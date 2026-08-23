# Chapter 20 — The fleet in one file

**Level:** Intermediate

So far you commanded one ship at a time: docker run, docker network, docker volume,
one piece at a time. But a real application is a fleet — a web, a database, a cache —
and coordinating it by hand, command after command, is fragile and unrepeatable. Part
6 introduces the tool that describes the whole fleet in a single file: Docker Compose.
In one file you declare the services, and Compose does the rest — it creates for you an
application network where services find each other by name (like the custom bridge of
chapter 17, but without writing it), respects dependencies, and starts or stops
everything with one command. In this lab you translate three docker run into a single
file: three services talking by name on a declared network, with a named volume for
the state, a fourth service that stays out of the startup because it belongs to a
profile, and an override file that changes web alone when you pass it.

## Objectives

- Describe a multi-service application in a single Compose file (20.1).
- Define the services with an image and a command (20.2).
- Declare a dependency between services with depends_on (20.3).
- See that the services resolve by name on the application network (20.3).
- Translate three docker run into one file: three services, a declared network and a
  named volume instead of three separate commands (20.3).
- Keep a service out of the default startup with profiles, and start it only when it
  is needed (20.4).
- Layer a development compose.override.yaml onto the base file, and see that it
  changes only what it declares (20.4).

## Prerequisites

- A Linux with Docker Engine running and the Docker Compose plugin (see SETUP.md).
  Your user must be able to use Docker.
- Chapter 17 (custom network, name resolution): Compose creates it for you. Chapters
  13-14 (volumes): you will compose those in the next chapters.

## The scenario

In start/ you will find compose.yaml: it describes db and web, but with no command to
keep them alive, no dependency, no network or volume, no third service and no
profiled one — so the app does not stay up and half the file is missing. You fill six
gaps (TODO 1..6).

Next to it there is compose.override.yaml, already complete: it is not a separate
application, it is the layer Compose merges onto the base file when you pass both.
The Compose project has a unique name and is removed at the end (down, profiles
included); the daemon is not touched nor restarted.

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

### Phase 3 — The network and the state, declared (20.3 — TODO 4)

Complete **TODO 4**: declare the application network and the named volume, and put
the services on them. Compose creates a network anyway, even if you do not write it:
the difference is that by declaring it you decide what it is called and who is on it,
instead of inheriting a default. The named volume is db's state, and it outlives the
container (chapter 13).

    networks:
      - appnet
    volumes:
      - dbdata:/var/lib/db

and, at the bottom of the file, the two declarations the services refer to:

    networks:
      appnet:

    volumes:
      dbdata:

On that network the embedded DNS resolves the service names, so web reaches db simply
as "db" — never by IP.

### Phase 4 — The third service (20.3 — TODO 5)

Complete **TODO 5**: add cache, the fleet's third ship. This is the point of the
chapter: three separate docker run, with their own networks and their own names to
remember, become three blocks inside the same sheet.

    cache:
      image: busybox
      command: sleep 3600
      networks:
        - appnet

### Phase 5 — The service that does not start (20.4 — TODO 6)

Complete **TODO 6**: declare tools inside a profile. A service with profiles exists
in the file but stays out of docker compose up: it starts only if you ask for it
explicitly, with --profile tools. It is how you keep in the same sheet the things you
rarely need — a debug service, a maintenance job — without having them started every
time.

    tools:
      image: busybox
      command: sleep 3600
      networks:
        - appnet
      profiles:
        - tools

### Phase 6 — The development layer (20.4)

Nothing to write here: compose.override.yaml is ready. It holds only what changes on
your machine — one variable for web — and repeats nothing else. Compose merges it onto
the base file service by service, but only if you pass it:

    docker compose -f compose.yaml -f compose.override.yaml up -d web

The test checks it both ways: with the base file alone the variable is not there,
with the override on top it is. That is how you keep a single model of the
application across environments, instead of two files drifting apart.

Once the six TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- compose.yaml defines db and web with a command that keeps them alive (TODO 1, 2).
- It declares that web depends on db (TODO 3).
- It declares the application network and the named volume, and puts the services on
  them (TODO 4).
- It adds the third service, cache (TODO 5).
- It declares tools inside a profile, so it does not start by default (TODO 6).
- run.sh prints OK 1..6 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh brings the application up and checks, point by point:

- **OK 1** — the three services (db, web, cache) are running after docker compose up;
  the fourth, the profiled one, is not.
- **OK 2** — web reaches db by service name: the application network has the embedded
  DNS.
- **OK 3** — the file declares that web depends on db (the dependency graph), from a
  single declarative file.
- **OK 4** — there is exactly one project network and all three services are on it;
  the named volume exists, and db has it mounted at /var/lib/db.
- **OK 5** — profiles: tools stays out of the default startup, and comes up only when
  asked for with --profile tools.
- **OK 6** — override: with compose.yaml alone the MODE variable does not exist; with
  the override merged on top it is development. Only what the override declares
  changes.

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

Nothing to tear down by hand: run.sh closes the project with docker compose down -v,
profiles included — removing the project's containers, network and named volume — with
a safety trap. The volume belongs to the test project, not to you. The busybox
base image stays in cache. The daemon is never restarted.

## Where it leads

You described an application in one file and started it with one command. But
"started" is not "ready": **chapter 21** tackles real dependencies — depends_on with a
condition, the healthchecks that say when a service is truly ready, and the startup
order that follows. For the Compose reference, see the volume's appendices.
