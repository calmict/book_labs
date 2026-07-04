# Chapter 23 — The Cardboard King (container security)

> Exercise for **Chapter 23 — Container security** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Advanced

## Objectives

By the end of this lab you will be able to:

- feel firsthand why root inside a container is a cardboard king: uid 0, yes, but the real power lives in the capabilities, the privileges and the filesystem — and in the kernel it shares with the host;
- harden a pod with the SecurityContext: non-root user, no escalation, read-only filesystem, all capabilities dropped, seccomp on — and verify each defence from the inside;
- move from pod-by-pod defence to defence at scale with Pod Security Standards: one label on the namespace, and admission refuses non-compliant pods before they are even born.

## Prerequisites

- Chapter 4 completed (capabilities dissected by hand: you will meet the very same hex CapEff here) and Chapters 21–22 (least privilege: here it reaches inside the container).
- The book-labs cluster running.
- Two manifests in start/: king.yaml (given) and hardened.yaml (TODO). The checkpoint (Pod Security Standards) is a label on the namespace: you will apply it by hand.

## Instructions

1. The naked king. Create the namespace and crown the king (no SecurityContext: it runs as root):

       kubectl create namespace throne
       kubectl apply -f king.yaml
       kubectl -n throne wait --for=condition=Ready pod/king --timeout=60s

   Now look in its pockets:

       kubectl -n throne exec king -- id
       kubectl -n throne exec king -- sh -c 'grep -E "CapEff|Seccomp" /proc/self/status'
       kubectl -n throne exec king -- sh -c 'echo treasure > /root/proof && echo WRITABLE'

   uid=0(root), CapEff 00000000a80425fb (the very number from chapter 4: a fistful of capabilities), Seccomp 0 (no syscall filter), and the root filesystem is writable. It looks like a king. On a kernel shared with the host, it is a dangerous one.

2. Stripping the king. Complete hardened.yaml by adding a securityContext to the container that: runs it as a non-root user (runAsNonRoot true, runAsUser 65534), forbids privilege escalation (allowPrivilegeEscalation false), makes the root read-only (readOnlyRootFilesystem true), drops ALL capabilities (capabilities.drop ["ALL"]) and turns on the default seccomp profile (seccompProfile.type RuntimeDefault). Apply and redo the same inspection:

       kubectl apply -f hardened.yaml
       kubectl -n throne wait --for=condition=Ready pod/hardened --timeout=60s
       kubectl -n throne exec hardened -- id
       kubectl -n throne exec hardened -- sh -c 'grep -E "CapEff|Seccomp" /proc/self/status'
       kubectl -n throne exec hardened -- sh -c 'echo treasure > /proof && echo WRITABLE' || echo "blocked (read-only)"

   uid=65534(nobody), CapEff 0000000000000000 (empty hands), Seccomp 2 (the filter is there), and the write fails: "Read-only file system". The crown was cardboard.

3. The checkpoint (Pod Security Standards). So far you hardened one pod at a time. Now post a guard at the namespace door: a single label that refuses at admission any pod that does not meet the restricted level.

       kubectl label namespace throne pod-security.kubernetes.io/enforce=restricted --overwrite

   Notice the Warning right away: it denounces the king already inside as a violation — but the king is NOT killed. Admission only checks at birth:

       kubectl -n throne get pod king

   is still Running. Instead, try to let a NEW root intruder in:

       kubectl -n throne run intruder --image=busybox:stable --restart=Never -- sleep infinity

   Refused to its face, with the exact list of what it lacks (allowPrivilegeEscalation, capabilities.drop, runAsNonRoot, seccompProfile). The hardened pod, on the other hand, walks past the guard — re-create it under restricted to see it admitted:

       kubectl -n throne delete pod hardened
       kubectl apply -f hardened.yaml

   Defence at scale: no longer pod by pod, but one gate for the whole namespace. And once again — as in chapter 22 — security is a matter of a single label.

4. Tear the kingdom down:

       kubectl delete namespace throne

## The questions for answers.md

- (a) SecurityContext and the shared kernel (23.1–23.2). Root in the container is not root on the host (user namespace, capabilities already trimmed by default): so why is it still dangerous? Explain what you read in CapEff (the chapter 4 number versus the zeros of the hardened pod) and what each defence protects: runAsNonRoot, allowPrivilegeEscalation false, readOnlyRootFilesystem, capabilities.drop ALL. Why, sharing the kernel with the host, does an escape cost more than in a VM?
- (b) Seccomp and MAC (23.3–23.4). What does the Seccomp field say (0 versus 2) and what does RuntimeDefault do? In one line, the difference between seccomp (filters syscalls) and AppArmor/SELinux (Mandatory Access Control over files and resources). Why is neither defence on by default?
- (c) Pod Security Standards (23.5). The three levels (privileged / baseline / restricted) and the three modes (enforce / audit / warn). Why did the label not evict the king already running, and what does that mean for anyone hardening an already-populated cluster? The parallel with chapter 22: pod-by-pod defence (SecurityContext) versus defence at scale (PSA on the namespace).

## Definition of "done"

- [ ] The naked king: uid 0, CapEff a80425fb, Seccomp 0, writable root — seen with your own eyes.
- [ ] The stripped king: non-root uid, CapEff all zeros, Seccomp 2, write refused.
- [ ] Under restricted: the root intruder refused at admission, the hardened pod admitted.
- [ ] answers.md answers the three questions.
- [ ] The throne namespace has been deleted.
