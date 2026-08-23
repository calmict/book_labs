# Chapter 15 — Answers

## The completed TODOs

**TODO 1 (15.2) — the mismatch: a non-owning UID is refused:**

    mismatch=$(docker run --rm --user "$OTHER_UID" -v "$HOSTDIR:/data" busybox sh -c 'touch /data/x 2>/dev/null && echo WROTE || echo DENIED')

**TODO 2 (15.3) — the cure: run as the owning UID:**

    match=$(docker run --rm --user "$HOST_UID" -v "$HOSTDIR:/data" busybox sh -c 'touch /data/ok 2>/dev/null && echo WROTE || echo DENIED')

**TODO 3 (15.1) — the UID crosses the boundary unchanged:**

    owner_uid=$(stat -c '%u' "$HOSTDIR/ok" 2>/dev/null || echo NONE)

**TODO 4 (15.1) — the root problem, reproduced:**

    ROOTDIR="$HOSTDIR/state"
    docker run --rm -v "$HOSTDIR:/data" busybox sh -c 'mkdir -p /data/state && echo seed > /data/state/f'
    root_owner=$(stat -c '%u' "$ROOTDIR/f")
    rm -rf "$ROOTDIR" 2>/dev/null && host_cleanup=REMOVED || host_cleanup=DENIED

The tree belongs to UID 0, and the removal is DENIED. Note where the refusal comes
from: deleting a file requires write permission on the folder that contains it, not
on the file. The file alone, sitting in a folder of yours, you could still delete —
what locks you out is the folder root created inside the mount.

**TODO 5 (15.2) — cure 1: the identity declared in the image:**

    docker build -q -t "$IMG_USER" --build-arg "APP_UID=$HOST_UID" -f "$HERE/Dockerfile.user" "$HERE" >/dev/null
    user_write=$(docker run --rm -v "$HOSTDIR:/data" "$IMG_USER" sh -c 'touch /data/by-user 2>/dev/null && echo WROTE || echo DENIED')
    user_owner=$(stat -c '%u' "$HOSTDIR/by-user" 2>/dev/null || echo NONE)

Same effect as --user, but the number travels with the image instead of with the
command line: nobody can forget the flag. The price is that the UID is baked in at
build time, so the image is tied to the host that owns the data — fine for an
application image built for its deployment, awkward for an image passed around
between machines whose users have different numbers.

**TODO 6 (15.3) — cure 2: fix the ownership, then hand over:**

    docker build -q -t "$IMG_ENTRY" -f "$HERE/Dockerfile.entrypoint" "$HERE" >/dev/null
    entry_uid=$(docker run --rm -e "TARGET_UID=$HOST_UID" -v "$HOSTDIR:/data" "$IMG_ENTRY" 'id -u; echo done > /data/state/written' | head -1)
    entry_owner=$(stat -c '%u' "$ROOTDIR/written" 2>/dev/null || echo NONE)
    rm -rf "$ROOTDIR" 2>/dev/null && after_cure=REMOVED || after_cure=DENIED

This is the pattern real images use: start as root because chown needs root, put the
mount right, then stop being root for the whole life of the process. The handover is
the important half. In fixperms.sh it is written

    exec su app -c "$*"

and the exec is what makes it a handover rather than a supervision: the shell is
replaced by the command, which stays PID 1 and receives signals first-hand (chapter
10). On a full base image the same line is written with gosu (Debian) or su-exec
(Alpine), tools that exist precisely to do this without dragging in a login session;
busybox's su already execs, so here it is enough.

The lab stops at these two cures. The third solution of the chapter, userns-remap
(15.4), is not reproduced: it is configured in the daemon and needs a restart of it,
which this lab never does — the daemon is shared, and other containers are running on
it.

## Reflection questions

**a. Why are permissions by numeric UID/GID, not by name?**

User and group names live in /etc/passwd and /etc/group, and those files are
per-filesystem: the host has its own, the image has its own, and they do not have to
agree. The kernel does not compare names — it stores and checks ownership as numbers.
When a container writes to a mounted file, the kernel sees the process's numeric UID
and the file's numeric owner and compares those; the name "appuser" the image gave to
UID 1000 (chapter 12) is just a local label that the host never consults. So on a
shared mount only the number matters: appuser=1000 in the image and your user=1000 on
the host are, to the kernel, the same identity, while appuser=1000 and a host owner of
5000 are strangers, whatever they are called.

**b. Three ways to make the numbers match.**

First, run the container with --user set to the UID that owns the files: nothing in
the image changes, but the caller must know and pass the right number, which is easy
in a script and awkward to standardise. Second, chown the mounted folder to the
container's UID: the data now fits the container, but you have changed ownership on
the host, which may not be yours to change and can break other users of that path.
Third, bake the user into the image with the same numeric UID as the data
(adduser -u 1000): the image is self-consistent and needs no --user, but it hard-codes
an assumption about the host's UIDs, which varies between machines. In development the
first is handiest; in production the third is cleanest when you control the numbering,
often combined with an entrypoint that fixes ownership on start.

**c. How does the USER namespace change the picture?**

Without a USER namespace, there is no remapping: UID N inside the container is UID N
on the host, which is exactly why the file the container created shows up owned by
your UID on the host, and why root in the container is root on the host for mounted
files. A USER namespace (chapter 2), used by rootless Docker and by userns-remap,
shifts a whole range: container UID 0 might map to host UID 100000, container 1000 to
100999, and so on. Then "root inside" is a harmless high UID outside, which is safer —
but it also means the numbers you must match are the mapped ones, so a bind-mounted
host file owned by 1000 is reached by the container UID that maps to host 1000, not by
container UID 1000. The rule is the same (match the numbers); userns just adds a
translation step you have to account for.
