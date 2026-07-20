# Chapter 23 — Answers

## The completed TODOs

**TODO 1 (23.2) — uid inside the user namespace:**

    inner_uid=$(unshare --user --map-root-user id -u)

**TODO 2 (23.3) — host owner of a file created "as root":**

    unshare --user --map-root-user sh -c "touch '$OUT/asroot'"
    owner_uid=$(stat -c '%u' "$OUT/asroot")

**TODO 3 (23.3) — can that root write the host's /etc:**

    host_write=$(unshare --user --map-root-user sh -c 'touch /etc/rootless-probe 2>/dev/null && echo YES || echo NO')

## Reflection questions

**a. Why is the docker group root on the host?**

The daemon runs as root and listens on a UNIX socket; the docker group grants write
access to that socket. But the API behind the socket can do anything the daemon can —
and the daemon is root. Whoever writes to it can, for instance, start a container that
bind-mounts the host's / read-write and runs as root, or that uses --privileged, and
from there read or change any file on the host, add a user, install a backdoor. So
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
container lands not as host root but as an unprivileged host user — it can damage only
what that user can, which is little. The whole class of "container escape = host root"
attacks loses its prize. The costs are real but bounded: an unprivileged user cannot
bind ports below 1024 (rootless works around it with slirp/rootlesskit or a port
helper), some storage drivers and features need real privilege, and performance can
differ. You accept these when the isolation is worth more than the convenience — which,
for anything multi-tenant or exposed, it usually is.
