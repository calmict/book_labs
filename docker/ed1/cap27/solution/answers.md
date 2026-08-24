# Chapter 27 — Answers

## The completed TODOs

**TODO 1 (27.2) — reclaim our stopped containers, scoped by label:**

    docker container prune -f --filter "label=owner=$LABEL" >/dev/null

**TODO 2 (27.2) — reclaim our named volume, by name:**

    docker volume rm "$VOL" >/dev/null

**TODO 3 (27.2) — recount, nothing of ours should remain:**

    con_after=$(docker ps -aq --filter "label=owner=$LABEL" | grep -c . || true)
    vol_after=$(docker volume ls -q --filter "label=owner=$LABEL" | grep -c . || true)

**TODO 4 (27.3) — back up the source volume and restore it into a new volume:**

    docker volume create --label "owner=$LABEL" "$BACKUP_VOL" >/dev/null
    docker run --rm -v "$BACKUP_VOL:/data" busybox sh -c 'printf "%s\n" "$1" > /data/message.txt' sh "$known_text"
    docker run --rm -v "$BACKUP_VOL:/data:ro" -v "$OUT:/backup" busybox tar czf "/backup/$(basename "$ARCHIVE")" -C /data .
    docker volume create --label "owner=$LABEL" "$RESTORE_VOL" >/dev/null
    docker run --rm -v "$RESTORE_VOL:/data" -v "$OUT:/backup:ro" busybox tar xzf "/backup/$(basename "$ARCHIVE")" -C /data
    restored_text=$(docker run --rm -v "$RESTORE_VOL:/data:ro" busybox cat /data/message.txt)
    [ "$restored_text" = "$known_text" ] && backup_match=true

**TODO 5 (27.3) — round-trip a scoped tag through a loopback registry:**

    docker run -d --name "$REGISTRY" --label "owner=$LABEL" -p 127.0.0.1::5000 registry:2 >/dev/null
    REG_PORT=$(docker port "$REGISTRY" 5000/tcp | sed 's/.*://')
    REGISTRY_TAG="127.0.0.1:$REG_PORT/cap27-image:cap27-$$"
    docker tag busybox "$REGISTRY_TAG"
    docker push "$REGISTRY_TAG" >/dev/null
    push_check_output=$(docker pull "$REGISTRY_TAG" 2>&1)
    pushed_digest=$(printf '%s\n' "$push_check_output" | sed -n 's/^[Dd]igest: \(sha256:[0-9a-f]*\).*/\1/p' | tail -n 1)
    docker image rm "$REGISTRY_TAG" >/dev/null
    pull_output=$(docker pull "$REGISTRY_TAG" 2>&1)
    pulled_digest=$(printf '%s\n' "$pull_output" | sed -n 's/^[Dd]igest: \(sha256:[0-9a-f]*\).*/\1/p' | tail -n 1)

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

**d. Why read-only backup and a new restore volume?**

Mounting the source read-only prevents the backup tool from altering the data it is meant
to protect. Restoring into a new volume preserves the source and lets you validate the
result before switching consumers to it. A production procedure should also quiesce or
snapshot a database so that related files represent one consistent point in time, record
and verify checksums, encrypt the archive, test restores regularly, and keep independent
copies according to a retention policy. A backup that has never been restored is only an
untested assumption.

**e. Why loopback here, and what changes on a real IP address?**

Binding the published port to 127.0.0.1 keeps the unauthenticated teaching registry off
the network and uses Docker's loopback exception for an HTTP registry. With a real IP,
Docker expects a trusted TLS endpoint unless the daemon is explicitly configured to allow
that insecure registry; changing that daemon-wide setting is inappropriate on a shared
host. A production registry also needs authentication and authorisation, trusted TLS,
storage backups, vulnerability and access controls, and retention or garbage-collection
policies so old manifests and blobs do not grow without bound.
