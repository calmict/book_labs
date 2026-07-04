# Chapter 23 — Answers (model solution)

## The naked king

    id:      uid=0(root) gid=0(root) groups=0(root),10(wheel)
    CapEff:  00000000a80425fb
    Seccomp: 0
    root filesystem: WRITABLE

## The stripped king

    id:      uid=65534(nobody) gid=65534(nobody) groups=65534(nobody)
    CapEff:  0000000000000000
    Seccomp: 2
    root filesystem: read-only (write refused)

## The checkpoint

    intruder REFUSED at admission (allowPrivilegeEscalation, capabilities.drop,
      runAsNonRoot, seccompProfile all missing)
    hardened ADMITTED and Running under enforce=restricted

## The three questions

**a. SecurityContext and the shared kernel (23.1-23.2): why is container
root still dangerous, what does CapEff tell you, and what does each
defence protect?**

Container root is not host root: the user namespace maps it, and the
runtime already trims the capability set — that is why the king's CapEff
is a80425fb and not the full 1ffffffffff we saw in chapter 4 on the host.
But a80425fb is still a fistful of dangerous capabilities (CHOWN,
DAC_OVERRIDE, SETUID, NET_RAW, KILL...), and — this is the crux — the
container shares the SAME kernel with the host. There is no hypervisor in
between: a single kernel bug plus enough capabilities, and root inside
becomes root outside. In a VM an escape must pierce virtualised hardware;
here it only has to fool one shared kernel, so the blast radius is the
whole node. Each SecurityContext setting narrows that radius: runAsNonRoot
/ runAsUser 65534 means the process is not uid 0 at all (CapEff drops to
zeros); capabilities.drop ALL takes away the fistful even if it were root;
allowPrivilegeEscalation false stops a setuid binary from regaining
privileges it just lost; readOnlyRootFilesystem stops an attacker from
writing tools or tampering with the image at runtime. Defence in depth:
no single setting is the wall, together they are.

**b. Seccomp and MAC (23.3-23.4): what does the Seccomp field mean, what
does RuntimeDefault do, and how does seccomp differ from AppArmor/SELinux?
Why is neither on by default?**

The Seccomp field in /proc/self/status is 0 when no syscall filter is
installed (the naked king) and 2 when a filter in "filter mode" is active
(the hardened pod). RuntimeDefault applies the container runtime's curated
seccomp profile, which blocks the dozens of rarely-needed, historically
dangerous syscalls (keyctl, ptrace of others, kernel module loading, raw
clocks...) while allowing everything a normal program uses. Seccomp works
at the syscall boundary — which kernel calls the process may make.
AppArmor and SELinux are Mandatory Access Control: they work at the
resource boundary — which files, paths, ports and capabilities a labelled
process may touch, enforced by the kernel regardless of file ownership.
Seccomp says "you may not CALL this"; MAC says "you may not TOUCH that".
Neither is on by default because both can break legitimate workloads
(a program that needs an unusual syscall, or a profile that forbids a path
the app reads), so Kubernetes leaves them opt-in — RuntimeDefault is the
safe, broadly-compatible baseline you should almost always opt into.

**c. Pod Security Standards (23.5): the three levels and three modes, why
the label did not evict the running king, and the parallel with
chapter 22.**

Three levels, increasingly strict: privileged (anything goes),
baseline (blocks the obvious escapes — no hostNetwork, no privileged, no
hostPath), restricted (the hardened-pod contract: non-root, drop ALL,
no escalation, seccomp RuntimeDefault). Three modes, chosen per label:
enforce (reject violating pods at admission), audit (allow but record in
the audit log), warn (allow but print a client Warning). You saw warn and
enforce together: labelling enforce=restricted printed a Warning naming
the king as a violator, yet did NOT evict it — because Pod Security is an
ADMISSION controller. It runs only when a pod is created or updated; it
never re-scans what is already running. The lesson for a populated
cluster: turn it on in warn/audit first to find your violators, fix or
exempt them, THEN switch to enforce — otherwise your existing pods keep
running non-compliant while new deployments break. The parallel with
chapter 22 is exact. There, one label (podSelector, and namespace labels)
governed the network; here one label governs admission. Both are defence
at SCALE — a namespace-wide gate — as opposed to the pod-by-pod hardening
of the SecurityContext. And both share the same caveat we keep meeting: a
policy only acts going forward, on the thing that passes through the gate,
never retroactively on what already slipped through.
