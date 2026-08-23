# Chapter 24 — Answers

## The completed TODOs

**TODO 1 (24.1) — default capabilities:**

    default=$(docker run --rm busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

**TODO 2 (24.1) — all dropped:**

    dropall=$(docker run --rm --cap-drop ALL busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

**TODO 3 (24.1) — only NET_RAW granted back:**

    dropadd=$(docker run --rm --cap-drop ALL --cap-add NET_RAW busybox sh -c 'ping -c1 -w2 127.0.0.1 >/dev/null 2>&1 && echo OK || echo FAIL')

**TODO 4 (24.1) — the same principle on a sharper key:**

    mount_default=$(docker run --rm busybox sh -c 'mkdir -p /mnt/t; mount -t tmpfs none /mnt/t >/dev/null 2>&1 && echo MOUNTED || echo DENIED')
    mount_added=$(docker run --rm --cap-add SYS_ADMIN busybox sh -c 'mkdir -p /mnt/t; mount -t tmpfs none /mnt/t >/dev/null 2>&1 && echo MOUNTED || echo DENIED')

DENIED, then MOUNTED. The container was root in both runs: what changed is one
capability. SYS_ADMIN is worth singling out because it is not one key among many - it
guards mounting, and a good deal besides, to the point that granting it is often
described as granting most of root back. When an image asks for it, the right question
is what exactly it needs to mount, and whether the mount can be done outside the
container instead.

**TODO 5 (24.2) — seccomp is a separate barrier:**

    seccomp_mode=$(docker run --rm busybox sh -c 'grep "^Seccomp:" /proc/self/status | tr -d "\t" | cut -d: -f2')
    unshare_default=$(docker run --rm busybox sh -c 'unshare -U true >/dev/null 2>&1 && echo ALLOWED || echo BLOCKED')
    unshare_unconfined=$(docker run --rm --security-opt seccomp=unconfined busybox sh -c 'unshare -U true >/dev/null 2>&1 && echo ALLOWED || echo BLOCKED')

Mode 2 is what the kernel reports when a seccomp filter is loaded for the process, and
Docker loads its default profile unless told otherwise. The measurement that matters is
the pair that follows: the same image, the same capabilities, the same command - BLOCKED
with the profile, ALLOWED without it. Nothing about root or about capabilities explains
the difference, so the refusal can only come from the syscall filter. This is why the
two mechanisms are worth keeping apart in your head: capabilities say what powers the
process holds, seccomp says which system calls it may make at all, and a container can
be stopped by either.

**TODO 6 (24.4) — what --privileged really grants:**

    caps_default=$(docker run --rm busybox sh -c 'grep "^CapEff:" /proc/self/status | tr -d "\t" | cut -d: -f2')
    caps_privileged=$(docker run --rm --privileged busybox sh -c 'grep "^CapEff:" /proc/self/status | tr -d "\t" | cut -d: -f2')
    mount_privileged=$(docker run --rm --privileged busybox sh -c 'mkdir -p /mnt/t; mount -t tmpfs none /mnt/t >/dev/null 2>&1 && echo MOUNTED || echo DENIED')

The effective mask goes from a reduced value to every bit lit, and the mount that was
denied in TODO 4 now succeeds with nothing asked for. That is the honest description of
the flag: it does not "run the container as root" - the container was already root - it
removes the restrictions that made root harmless. Read next to TODO 4, it makes the
practical rule obvious: when something is refused, find the one capability that was
missing and grant that, because reaching for --privileged also silently hands over
everything you never meant to give.

## Reflection questions

**a. Why is drop-all-then-add-one the purest least privilege?**

Historically a process was either root (all-powerful) or not; capabilities break root's
omnipotence into dozens of independent grants — NET_RAW for raw sockets, NET_BIND_SERVICE
for ports below 1024, SYS_ADMIN for mounting, CHOWN, SETUID, and so on. Starting from
--cap-drop ALL means the container begins with none of them, and each --cap-add is a
deliberate, auditable decision to grant exactly one power because the app provably needs
it. That is least privilege in its strictest form: you enumerate what is required
instead of trusting a default. Docker already helps by dropping many capabilities from
the default set (a container is not full root), but the default is a compromise; dropping
all and adding back is how you tighten a specific service to only what it uses — in the
lab, one key, NET_RAW, and nothing else.

**b. How is seccomp complementary to capabilities?**

Capabilities gate privileged operations; seccomp gates the system calls themselves. They
are different axes: a syscall can be dangerous even without a special capability, and the
default seccomp profile blocks a long list of them (keyctl, add_key, ptrace against other
processes, obscure or rarely-needed calls) so that a compromised process cannot even ask
the kernel to do them. It is complementary because it narrows the interface to the kernel
regardless of which capabilities remain: fewer syscalls reachable means fewer bugs
reachable. Disabling it with --security-opt seccomp=unconfined hands the container the
full syscall surface, re-opening that class of attacks; it is justified only for
deliberate debugging of something the default profile blocks, never as a convenience.

**c. Why are AppArmor/SELinux a third layer?**

Capabilities and seccomp limit what a process can do to the kernel; AppArmor and SELinux
limit what it can touch in the system — which files, which paths, which network
operations — by policy, independent of the process's uid or capabilities. On
Debian/Ubuntu that is AppArmor (per-program profiles); on RHEL/Fedora, this machine
included, it is SELinux (labels on processes and files, checked on every access). They
are a third layer because even a process that has a capability and a permitted syscall is
still stopped if the mandatory policy forbids the specific object it targets. Stacked —
least-privilege capabilities, a restrictive seccomp profile, and a MAC confining access —
they give defence in depth: an attacker must defeat all three, not one, to turn a
compromised container into a compromised host.
