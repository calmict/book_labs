# Chapter 3 — Limiting CPU and RAM by hand

**Level:** Foundational

Namespaces decide what a process sees; now you directly observe the counters that decide how much it may consume.

## Objectives

- Create a cgroup v2 and read its available controllers (3.1, 3.2).
- Observe the different outcomes of CPU and memory limits: throttling and an OOM kill (3.3).
- Verify the process limit and connect the controllers to Kubernetes limits (3.3, 3.4).

## Prerequisites

- Linux with cgroup v2 and a systemd user session that delegates the memory and pids controllers.
- systemd-run and Python 3. No root privileges and no Kubernetes cluster.
- Trying cpu.max personally requires a disposable Linux environment with the cpu controller available; run.sh reports the step without attempting it when cpu is not delegated.
- Chapter 2 completed.

## The scenario

The start/ directory contains cage.sh, a valid but incomplete script. Its three gaps create and inspect a delegated cgroup, impose a memory ceiling, and limit processes.

    cd kubernetes/ed1/cap03/start

### Phase 1 — The cage and its controllers (3.1, 3.2 — TODO 1)

The lab-cap03 directory is a real cgroup. Read cgroup.controllers and verify that memory and pids are available in the user subtree.

### Phase 2 — CPU time (3.3)

The lesson's limit remains cpu.max set to 20000 100000, or 20 percent of one core. The cpu controller is not delegated to this machine's user session: run.sh keeps this step as the sole SKIP and reports the measurement that shows why it would not be a valid test.

### Phase 3 — The memory ceiling (3.3 — TODO 2)

Use a user scope with MemoryMax=20M and MemorySwapMax=0 to run a process that attempts to allocate 200 MiB. It must die with exit 137. Repeat without the limit: the ALLOCATED output is the counter-test that makes the gate bite.

### Phase 4 — The fork bouncer (3.3 — TODO 3)

Use TasksMax=3 and start more processes than the scope can accept. Bash must report Resource temporarily unavailable.

Then run the complete check:

    cd ../solution
    bash run.sh

## "Done" criteria

- The delegated cgroup is created and exposes memory and pids.
- The limited process dies with exit 137, while the same unrestricted allocation succeeds.
- TasksMax genuinely rejects a fork beyond the limit.
- run.sh prints OK 1, SKIP 2, OK 3, OK 4, and ALL CHECKS PASSED.

## How it is verified

- OK 1 creates the cgroup and reads the controllers that are actually delegated.
- SKIP 2 documents why CPU throttling cannot be verified in the user slice and includes the supporting measurement.
- OK 3 contrasts death under MemoryMax with successful allocation without the limit.
- OK 4 checks the fork error produced by TasksMax=3.

## Reflection questions

**a.** Why does CPU slow down while memory can kill?

**b.** How do cpu.max and memory.max become a Pod's limits?

**c.** What do nr_throttled, oom_kill, and pids.max reveal during troubleshooting?

## Cleanup

run.sh uses automatically collected scopes and removes the lab-cap03 cgroup created in the user subtree. It leaves no laboratory process or cgroup behind.

## Where it leads

Chapter 4 combines namespaces and cgroups in the runtime Kubernetes uses to execute containers.
