# Chapter 25 — Answers

## The completed TODOs

**TODO 1 (25.1) — the container's logs:**

    logs=$(docker logs "$C" 2>&1)

**TODO 2 (25.2) — the logging driver:**

    driver=$(docker inspect -f '{{.HostConfig.LogConfig.Type}}' "$C")

**TODO 3 (25.3) — a live metric:**

    mem=$(docker stats --no-stream --format '{{.MemUsage}}' "$C")

## Reflection questions

**a. Why log to stdout/stderr instead of a file inside the container?**

Because the container is ephemeral (chapter 13): a log file written inside its writable
layer dies with the container, and to read it you would have to know its path, exec in,
and copy it out before it is gone. Writing to stdout and stderr instead hands the two
streams to the daemon, which captures them through the logging driver and keeps them
outside the container's own filesystem — so docker logs works even after the process has
exited, and the same mechanism works for every container regardless of what is inside. It
is why the twelve-factor guidance is "treat logs as event streams": the app just writes,
the platform handles collection, rotation and shipping.

**b. Where json-file logs go, and the other drivers.**

The default json-file driver writes each container's stdout/stderr as JSON lines to a
file under /var/lib/docker/containers/<id>/. Convenient, but unbounded: a chatty
container can fill the disk, because nothing rotates the file unless you say so — hence
max-size and max-file (per container or in the daemon config) to cap and roll it. The
other drivers exist for when logs must leave the host: journald hands them to systemd's
journal, syslog to a syslog server, fluentd/gelf/awslogs and the cloud drivers ship them
to a centralised pipeline. On a fleet you do not read logs host by host; you send them
somewhere they can be searched and correlated.

**c. Why continuous monitoring on top of stats/top?**

docker stats and docker top answer "what is happening right now" — a live snapshot of CPU,
memory, processes. They cannot answer "what happened at 3am", "is memory trending up over
a week", or "alert me when it crosses a threshold", because they keep no history and raise
no alarms. Production needs that: a monitoring stack (Prometheus scraping metrics, Grafana
charting them, alertmanager or the cloud's agents paging you) sits above these commands to
store, visualise and act. The need only grows with scale — one host you can watch by hand;
a cluster of many nodes and hundreds of containers you cannot, which is why Kubernetes
environments come with metrics and logging pipelines built in.
