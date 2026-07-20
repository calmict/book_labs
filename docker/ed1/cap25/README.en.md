# Chapter 25 — The logbook and the gauges

**Level:** Advanced

Security prevents; observability lets you see. When a service misbehaves in production,
the first question is always the same: what is it doing? Docker answers with two tools.
The logbook is the logs: everything the container writes to standard output and standard
error is captured by the daemon and made available with docker logs — even after the
fact, even after the process has died. The gauges are the metrics: docker stats shows, in
real time, the CPU, memory and network of each container. In this lab you read a
container's logbook — both stdout and stderr — find where Docker keeps it (the logging
driver) and read its live consumption.

## Objectives

- Retrieve with docker logs what a container writes to stdout and stderr (25.1).
- Recognise the logging driver that keeps those logs — the default json-file (25.2).
- Read a container's live metrics with docker stats (25.3).
- Frame observability in production (25.4).

## Prerequisites

- A Linux with Docker Engine running (see SETUP.md). Your user must be able to use
  Docker.
- Chapter 7 (the lifecycle and exit codes): here you add what the container says about
  itself while it lives.

## The scenario

In start/ you will find iobs.sh: a script that starts a container writing to stdout and
stderr and should read its logs, driver and consumption — but the three reads are missing.
You fill three gaps (TODO 1..3). Throwaway container (--rm/rm), the daemon is not touched.

Prepare the environment:

    cd docker/ed1/cap25/start

### Phase 1 — The logbook: docker logs (25.1 — TODO 1)

Open start/iobs.sh and complete **TODO 1**: read the container's logs. Docker captures
both stdout and stderr; merging the two streams (2>&1) retrieves them both.

    logs=$(docker logs "$C" 2>&1)

### Phase 2 — Where the logbook goes (25.2 — TODO 2)

Complete **TODO 2**: read the container's logging driver. It is what keeps the logs — by
default json-file, that is JSON files on disk managed by the daemon.

    driver=$(docker inspect -f '{{.HostConfig.LogConfig.Type}}' "$C")

### Phase 3 — The gauges: docker stats (25.3 — TODO 3)

Complete **TODO 3**: read a live metric, the memory usage. docker stats gives real-time
consumption; with --no-stream you take a snapshot.

    mem=$(docker stats --no-stream --format '{{.MemUsage}}' "$C")

Once the three TODOs are filled, run the test:

    cd ../solution
    ./run.sh

## "Done" criteria

- iobs.sh reads the container's logs (stdout and stderr) (TODO 1).
- It reads the logging driver (TODO 2).
- It reads the memory usage with docker stats (TODO 3).
- run.sh prints OK 1..3 and ALL CHECKS PASSED.

## How it is verified

solution/run.sh runs the scenario and checks, point by point:

- **OK 1** — docker logs retrieves both the line written to stdout and the one to stderr.
- **OK 2** — the container's logging driver is json-file (where the logs are kept).
- **OK 3** — docker stats reports a live metric: the container's memory usage.

## Reflection questions

**a.** The good practice is to write logs to stdout/stderr, not to a file inside the
container: why? What does Docker do with those two streams, and how does this connect to
the container being ephemeral (chapter 13) — a log file inside would vanish with it, a
stream captured by the daemon would not?

**b.** The default json-file driver writes logs to disk (under /var/lib/docker), and
without rotation they grow without bound until the disk fills. How do you cap them
(max-size/max-file options), and what are the other drivers — journald, syslog, fluentd,
the cloud drivers — for, when logs must leave the host toward a centralised system?

**c.** docker stats and docker top give a live snapshot, but no history and no alerts.
Why does production need continuous monitoring tools (Prometheus, Grafana, the cloud's
agents) on top of these commands, and how does that need amplify going from one host to an
orchestrated cluster?

## Cleanup

Nothing to tear down by hand: the container is removed by the script (docker rm -f, plus a
safety trap). The busybox base image stays in cache. The daemon is never restarted.

## Where it leads

You can read what a container says about itself. **Chapter 26** puts these tools to work
in the worst case: troubleshooting — containers that say nothing (empty logs), containers
that restart forever (the crash loop) — and how you get to the cause. For the command
reference, see the volume's appendices.
