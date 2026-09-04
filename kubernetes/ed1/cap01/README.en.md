# Chapter 1 — A container is just a process

**Level:** Foundational

The journey starts below Kubernetes: you observe a real process through the two views that make a container look like a separate machine.

## Objectives

- Observe the same process from the host and the container (1.2).
- Compare its PID, hostname and process list (1.2, 1.3).
- Distinguish process isolation from hardware virtualisation (1.3).

## Prerequisites

- Linux with a working Docker installation and daemon access.
- With Docker Desktop, run the lab in the daemon's Linux host: its PID does not belong to the WSL distribution.
- No Kubernetes cluster.

## The scenario

The start/ directory contains observe.sh, a valid but incomplete script. Fill three gaps to record both views of the same process.

    cd kubernetes/ed1/cap01/start

### Phase 1 — The host PID (1.2 — TODO 1)

Use docker inspect to obtain the PID assigned by the kernel to the sleep process.

### Phase 2 — The outside view (1.2 — TODO 2)

Write the PID, hostname and process count seen from the host to host.txt.

### Phase 3 — The inside view (1.3 — TODO 3)

Use docker exec to record the same data in inside.txt, then run the check:

    cd ../solution
    ./run.sh

## "Done" criteria

- The process has an ordinary host PID and PID 1 in the container.
- The hostname and process list show isolated views.
- run.sh prints OK 1..4 and ALL CHECKS PASSED.

## How it is verified

- OK 1 compares both PIDs of the same process.
- OK 2 checks the private hostname.
- OK 3 checks the restricted process list.
- OK 4 proves the contrast: with host PID mode the process is not PID 1.

## Reflection questions

**a.** How can two PIDs identify the same process?

**b.** What do the hostname and process list isolate without creating a new kernel?

**c.** What does the contrast with host PID mode prove?

## Cleanup

run.sh removes both containers and the temporary directory even after an error.

## Where it leads

Chapter 2 rebuilds these views directly with Linux namespaces, without a runtime.
