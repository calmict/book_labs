# Chapter 23 — Answers

## The completed TODOs

**TODO 1 (23.2) — uid inside the user namespace:**

    inner_uid=$(unshare --user --map-root-user id -u)

**TODO 2 (23.3) — host owner of a file created "as root":**

    unshare --user --map-root-user sh -c "touch '$OUT/asroot'"
    owner_uid=$(stat -c '%u' "$OUT/asroot")

**TODO 3 (23.3) — can that root write the host's /etc:**

    host_write=$(unshare --user --map-root-user sh -c 'touch /etc/rootless-probe 2>/dev/null && echo YES || echo NO')

**TODO 4 (23.1) — direct denial and daemon-mediated uid 0 access** (the probe path
is chosen by the script: the first of /root and /var/lib/docker your own user cannot
open):

    direct_read=$(ls -A "$probe" >/dev/null 2>&1 && echo YES || echo NO)
    root_probe=$(docker run --rm --name "$ROOT_CONTAINER" -v /:/host:ro "$IMAGE" sh -c 'printf "%s:%s:%s:" "$(id -u)" "$(stat -c %u "/host$1")" "$(stat -c %a "/host$1")"; ls -A "/host$1" >/dev/null 2>&1 && echo YES || echo NO' sh "$probe")

**TODO 5 (23.4) — the same mount as the unprivileged host uid:**

    user_read=$(docker run --rm --name "$USER_CONTAINER" --user "$outer_uid:$outer_gid" -v /:/host:ro "$IMAGE" sh -c 'ls -A "/host$1" >/dev/null 2>&1 && echo YES || echo NO' sh "$probe")

## Reflection questions

**a. Why is the docker group root on the host?**

The daemon runs as root and listens on a UNIX socket; the docker group grants write
access to that socket. But the API behind the socket can do anything the daemon can —
and the daemon is root. The lab demonstrates the safe, read-only form: the ordinary
host user is denied on a root-owned path, but a uid 0 container opens it through a
read-only bind mount, and the same container asked to run as your own uid is denied
again. A malicious request would ask for a read-write mount instead. So
"member of the docker group" is not a lesser privilege than root; it is root, one
docker run away (you met this in chapter 5, following a request from the socket to the
kernel). That is precisely the exposure rootless mode removes.

**b. What does "namespaced capabilities" mean?**

Inside a USER namespace the kernel gives you a full capability set (CapEff shows every
bit), but those capabilities are scoped to that namespace and the objects it owns.
Your namespace-root can create namespaces, mount inside its own mount namespace, chown
files it owns within the mapping — but it holds no power over resources owned by the
real root outside. That is why, in the lab, the file you create "as root" is owned on
the host by your ordinary UID (the mapping root->your-uid, the same numeric reasoning
as chapter 15), and why that root cannot write /etc: on the host it is just your
unprivileged user wearing a crown that only counts indoors.

**c. Why does rootless shrink the blast radius, and what are its limits?**

If the daemon and containers run inside such a mapping, then a process that escapes the
container lands not as host root but as an unprivileged host user — it can affect only
what that user can, which is little. The whole class of "container escape = host root"
attacks loses its prize. The costs are real but bounded: an unprivileged user cannot
bind ports below 1024 (rootless works around it with slirp/rootlesskit or a port
helper), some storage drivers and features need real privilege, and performance can
differ. You accept these when the isolation is worth more than the convenience — which,
for anything multi-tenant or exposed, it usually is.
