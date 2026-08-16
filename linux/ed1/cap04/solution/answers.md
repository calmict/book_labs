# Chapter 4 — Answers (model solution)

## Distribution identity

The values must be copied from /etc/os-release. ID is the specific distribution;
VERSION_ID identifies its release; ID_LIKE is a compatibility-family hint and may
be absent. PRETTY_NAME is a display label, not the best field for scripts.

## Package management

The executable and the package database must agree. Typical pairs are dnf with
rpm, apt-get with dpkg-query, zypper with rpm, pacman with its own database, and
apk with its own database. Finding an unrelated command on PATH is weaker evidence
than successfully querying the database used by the installed system.

## Kernel comparison

uname -r is authoritative for the running kernel. The package database describes
files installed in this filesystem. A matching package confirms that the running
release is installed locally. A mismatch can be legitimate in a container, after
an upgrade before reboot, or when old kernels remain installed alongside the
active one.

## Filesystem layout

findmnt identifies the source backing each mount target. A directory is on a
separate block-backed filesystem when its normalized source differs from the
source for /. Text in square brackets denotes a bind-mounted subtree and must not
be counted as another independent partition. lsblk provides the complementary
view from block devices to their mount points.
