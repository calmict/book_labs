# Chapter 27 — Answers

## The completed TODOs

**TODO 1 (27.2) — reclaim our stopped containers, scoped by label:**

    docker container prune -f --filter "label=owner=$LABEL" >/dev/null

**TODO 2 (27.2) — reclaim our named volume, by name:**

    docker volume rm "$VOL" >/dev/null

**TODO 3 (27.2) — recount, nothing of ours should remain:**

    con_after=$(docker ps -aq --filter "label=owner=$LABEL" | grep -c . || true)
    vol_after=$(docker volume ls -q --filter "label=owner=$LABEL" | grep -c . || true)

## Reflection questions

**a. Why is an unscoped prune dangerous, and how does scope make it safe?**

docker system prune -a reclaims everything the daemon considers unused: stopped
containers, dangling and unreferenced images, unused networks, the build cache — and with
--volumes, volumes too. On your own laptop that is fine; on a shared host it is a foot-gun,
because "unused" is judged daemon-wide, so it happily deletes the stopped container a
colleague meant to inspect, the base image another project just pulled, or a volume with
data no running container currently mounts. Scope is the fix: label your resources
(--label owner=me) and reclaim only those (--filter label=owner=me), or remove by explicit
name. You never say "everything"; you say "these, mine". The lab does exactly that, and
nothing outside its label is touched.

**b. What consumes space, and why is maintenance a routine?**

docker system df breaks it down: images (usually the largest, especially many tags and
layers), containers (their writable layers, which grow as they run), local volumes (data
that outlives containers, chapter 13), and the build cache (which balloons with frequent
builds). In a real environment images and the build cache tend to dominate, and log files
(chapter 25) quietly grow under them. Left alone, all of this fills the disk, and a full
disk takes the whole host down — builds fail, the daemon misbehaves, containers cannot
write. That is why cleanup is a scheduled routine (prune policies, log rotation, image
retention), not something you scramble to do when df hits 100%.

**c. Where the single host ends and orchestration begins.**

One host has hard ceilings: if it dies, everything on it dies with it (no high
availability); to serve more traffic you must start and wire copies by hand (no automatic
scaling); a crashed container comes back only if a restart policy happens to catch it (no
real self-healing across machines). An orchestrator crosses that boundary — it schedules
containers across many hosts, reschedules them when a node fails, scales replicas up and
down, and heals to a declared state. And the vocabulary is the one you now own: images,
networks, volumes, service names, healthchecks, secrets, least privilege. Kubernetes is
that orchestrator, and this manual has been its foundation — appendix E and the Kubernetes
book take you across.
