# Chapter 2 — Answers (model solution)

## Process tree seen from inside (ps aux)

    PID   USER     TIME  COMMAND
        1 root      0:00 /bin/sh
        6 root      0:00 ps aux

## Hostname: container vs host

    container: hand-made-container
    host:      myworkstation

## Namespace inodes: container vs host

    # inside the container            # on the host
    pid:  pid:[4026532704]            pid:  pid:[4026531836]
    uts:  uts:[4026532698]            uts:  uts:[4026531838]
    net:  net:[4026532705]            net:  net:[4026531840]
    user: user:[4026532319]           user: user:[4026531837]

(the exact inode numbers change on every run: what matters is which pairs
match and which do not)

The pid, uts and net inodes always differ: those are the namespaces we asked
unshare to create. The user namespace is the telling one: in the sudo variant
it is identical on both sides (we never isolated it, the container root IS the
host root), while in the rootless variant it differs, because a new user
namespace is exactly what grants an unprivileged user the right to create all
the other namespaces.

## The three questions

**1. In what sense is your unshare command conceptually equivalent to the
docker run of chapter 1?**

Both end up doing the same fundamental thing: they ask the kernel to start an
ordinary Linux process wrapped in a set of new namespaces, so that the process
gets a private view of PIDs, hostname, network and mounts. Docker adds a lot
of machinery around it, but the isolation itself is these same syscalls —
there is no "container object" in the kernel, only namespaces applied to a
process.

**2. What did you NOT get compared to a real container (images and layers,
resource limits, security)?**

- No image machinery: we unpacked a tarball by hand; no layers, no
  copy-on-write filesystem, no registry (chapter 4).
- No resource limits: the process can use all the CPU and RAM of the host —
  that is the job of cgroups (chapter 3).
- Much weaker security: no capability dropping, no seccomp filter, and chroot
  is not a security boundary the way pivot_root is; a real runtime does all of
  this for you (chapter 4).
- No networking beyond isolation: the container has a dead loopback and no way
  to talk to anything; a real runtime wires up veth pairs and NAT (chapter 6).

**3. Why is the --fork option needed together with --pid?**

Because of how the PID namespace works: the unshare() syscall does not move
the calling process into the new PID namespace — an existing process cannot
change its own PID. Only the children created afterwards enter it, and the
first child becomes PID 1. So unshare must fork: the parent stays outside,
and it is the forked child (our shell) that is born inside the new namespace
as PID 1. You can verify this from the host: the intermediate process still
shows the host pid namespace in /proc/[pid]/ns/pid, but a new value in
pid_for_children.
