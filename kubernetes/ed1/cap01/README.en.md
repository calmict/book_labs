# Chapter 1 — A Container Is Just a Process (See It for Yourself)

> Exercise for **Chapter 1 — The Problem Containers Solve** of the
> *Kubernetes Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:
- distinguish what a container actually isolates compared to a virtual machine;
- observe a "containerized" process simultaneously from the host and from inside the container, to see firsthand that it is the same Linux process viewed from two different angles;
- connect this hands-on observation to the chapter's theoretical concept: process isolation vs hardware virtualization.

## Prerequisites

- A Linux host (native or VM) with terminal access.
- Docker or Podman installed and working (try "docker run hello-world" or equivalent).

> ⚠️ **Note for WSL2 / Docker Desktop:** with Docker Desktop the daemon runs in a
> separate VM, so in step 3 the PID returned by docker inspect does **not
> exist** in your WSL distro and the ps command of step 3 will fail. On WSL2 use
> **Podman** (which runs inside your distro), or run the step 3 commands inside
> the docker-desktop distro.
- No Kubernetes cluster required: this chapter works below Kubernetes, not inside it.
- Basic command-line familiarity (ps, grep).

## Instructions

1. On the host, start a long-running container:

       docker run -d --name lab-cap01 alpine:3 sleep infinity

   (or the equivalent command to start a "sleep infinity" process inside a container).

2. From the host, find the PID of the sleep process as the kernel sees it:

       docker inspect --format '{{.State.Pid}}' lab-cap01

3. Inspect that PID directly from the host, without going through docker exec:

       ps -p <PID> -o pid,ppid,cmd
       cat /proc/<PID>/status | head -5

4. Now enter the container and look at the very same process from its own point of view:

       docker exec lab-cap01 ps aux

   Note the PID the process sees for itself from inside.

5. Compare the two PID numbers (host vs container) and write down your answer in an answers.md file to submit: why are they different even though it's the exact same process? What does this tell you about "isolation" as opposed to "virtualization"?

6. Repeat the comparison for the hostname (run hostname on the host, then "docker exec lab-cap01 hostname") and the full process list (ps aux on the host and inside the container).

7. Stop and remove the lab container:

       docker rm -f lab-cap01

## Definition of "done"

- [ ] You have the process's PID as it appears on the host and as it appears inside the container, and they are different numbers.
- [ ] Your answers.md file contains an explanation (even a brief one, 4-6 lines) of why the same process has two different PIDs, connecting it to the idea of "a Linux process seen through a different window" rather than "a separate machine".
- [ ] You verified that the hostname seen from inside the container differs from the host's.
- [ ] The lab container has been removed at the end of the exercise.
