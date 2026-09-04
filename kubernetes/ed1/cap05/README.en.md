# Chapter 5 — Climb the runtime chain

**Level:** Foundational

You built a container's pieces by hand; now follow who assembles them. Start from the live process,
climb to the shim, query containerd, and finally hand a bundle directly to runc.

## Objectives

- Trace the real chain between workload, shim, and init (5.2).
- Query containerd without going through the Docker CLI (5.1, 5.3).
- Read namespaces, cgroups, capabilities, and rootfs in the OCI bundle (5.3).
- Start a process with runc alone (5.2, 5.3).

## Prerequisites

- A Linux host with Docker, runc, ctr, jq, ps, awk, and tar.
- Access to the Docker daemon; neither sudo nor privileged containers are required.
- The docker:29-dind image for the automatic helper: when the containerd socket cannot be read
  directly, it is mounted in the helper together with a read-only task directory.

## The scenario

In start/runtime-lab.sh the sequence is already laid out but three pieces of evidence are missing.
Complete them without changing the sleep infinity workload or replacing the real chain with a simulation.

    cd kubernetes/ed1/cap05/start

### Phase 1 — From the process to init (5.2 — TODO 1)

Obtain the PID with docker inspect and follow the fourth field of proc/PID/stat. Write each PID and
name pair to parent-chain.txt: the step through containerd-shim is the required evidence.

### Phase 2 — Bypass Docker (5.1, 5.3 — TODO 2)

Use ctr in the logical moby namespace and save the task list. Copy the live config.json as well. If
host permissions deny direct access, use the non-privileged helper described under Prerequisites; the
task directory must remain read-only.

### Phase 3 — Only runc (5.3 — TODO 3)

Export the rootfs, generate a rootless spec, and replace the interactive shell with a batch command
that records PID and hostname. Start the bundle with runc, then run:

    cd ../solution
    ./run.sh

## Definition of "done"

- The chain shows the workload, containerd-shim, and then init.
- ctr lists the same ID and config.json contains the ingredients from chapters 2-4.
- The process started by runc alone appears as PID 1.
- run.sh prints OK 1..5 and ALL CHECKS PASSED.

## How it is verified

- OK 1 checks the real parent chain.
- OK 2 compares the Docker ID with the task seen by ctr.
- OK 3 reads namespaces, resources, capabilities, and root from the live bundle.
- OK 4 runs the rootless bundle with runc and verifies PID 1.
- OK 5 is the gate: with the spec's default process, the required evidence is absent.

## Reflection questions

**a.** Why is the shim the direct parent, while dockerd and containerd are not workload ancestors?

**b.** Reconstruct the CLI, dockerd, containerd, shim, runc, and process chain. What does moby prove?

**c.** Where do chapters 2-4 appear in config.json, and what does runc do after creation?

## Cleanup

The trap removes both containers and the temporary directory. The helper ends after each read; the
socket is not changed and the task directory is mounted read-only.

## Where it leads

Runc can create an isolated process, but it does not build its network. Chapter 6 takes veth pairs and
a bridge and wires by hand the path a runtime prepares for every container.
