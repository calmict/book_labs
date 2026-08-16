# Chapter 11 — Watch the Scheduler Decide

> Exercise for **Chapter 11 — The Scheduler: Who Runs, and for How Long** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Intermediate

## Objectives

By the end of this lab you will be able to:

- observe several CPU-bound processes sharing a limited CPU quota;
- measure the CPU effect of nice and distinguish it from I/O priority;
- recognize high load with mostly idle CPUs by reading load average, runnable processes, and CPU use together.

## Prerequisites

- A Linux host with Bash, a working Docker installation, and permission to start containers.
- The alpine:3.20 image available locally, or access to download it.
- Familiarity with ps, nice, dd, /proc/loadavg, and docker stats.

Every workload is confined to an ephemeral container with a CPU quota, memory limit, process limit, and explicit duration. Do not run the load generators directly on the host.

## Instructions

1. Copy start/container_lab.sh to a working directory and complete its four modes. Every mode must stop background processes even after an error or signal.

2. Start four CPU-bound processes in a container limited to two CPUs and measure the CPU ticks each process accumulates over four seconds:

       timeout --signal=TERM --kill-after=2s 15s docker run --rm \
         --name labcap11-cpu --cpus=2 --memory=128m --pids-limit=64 \
         --network none -v "$PWD/container_lab.sh:/lab/container_lab.sh:ro" \
         alpine:3.20 sh /lab/container_lab.sh cpu

   The values will not be identical, but they should show the four processes receiving comparable shares of the two available CPUs.

3. Repeat the CPU workload on one CPU, assigning nice 0 to one process and nice 15 to the other. Compare their accumulated ticks:

       timeout --signal=TERM --kill-after=2s 15s docker run --rm \
         --name labcap11-nice --cpus=1 --memory=128m --pids-limit=64 \
         --network none -v "$PWD/container_lab.sh:/lab/container_lab.sh:ro" \
         alpine:3.20 sh /lab/container_lab.sh nicecpu

   Under CPU contention, the nice 0 process must receive substantially more CPU time than the nice 15 process.

4. Run two identical dd writes concurrently, one at nice 0 and the other at nice 15, using files inside the container only:

       timeout --signal=TERM --kill-after=2s 20s docker run --rm \
         --name labcap11-io --cpus=2 --memory=192m --pids-limit=64 \
         --network none -v "$PWD/container_lab.sh:/lab/container_lab.sh:ro" \
         alpine:3.20 sh /lab/container_lab.sh io

   Compare elapsed times and throughput. Do not expect a stable ordering: nice controls CPU contention and does not directly assign I/O priority. The result also depends on the I/O scheduler, filesystem, cache, and underlying storage. Record the host devices' schedulers by reading the queue/scheduler files under /sys/block.

5. Start twelve runnable processes in a container limited to one quarter of a CPU. The limit leaves almost all host CPU capacity idle while waiting runnable processes raise the load:

       docker run -d --rm --name labcap11-load --cpus=0.25 --memory=128m \
         --pids-limit=64 --network none \
         -v "$PWD/container_lab.sh:/lab/container_lab.sh:ro" \
         alpine:3.20 sh /lab/container_lab.sh load
       sleep 5
       docker exec labcap11-load cat /proc/loadavg
       docker stats --no-stream labcap11-load
       timeout --signal=TERM --kill-after=2s 15s docker wait labcap11-load

   Read the runnable-process count in /proc/loadavg together with the capped percentage in docker stats. High load does not automatically mean that every physical CPU is busy.

6. Remove any remaining containers and record measurements and interpretation in observations.md:

       docker rm -f labcap11-cpu labcap11-nice labcap11-io labcap11-load

   The solution automates the complete experiment:

       ./solution/run.sh

## Definition of "done"

- [ ] Every docker run command has an explicit --cpus limit and ends within a few seconds.
- [ ] You observed four processes sharing two CPUs and recorded each process's ticks.
- [ ] Under CPU contention, the nice 0 process accumulated more ticks than the nice 15 process.
- [ ] The dd comparison documents that nice alone does not guarantee I/O priority and identifies the other relevant variables.
- [ ] You recognized many runnable processes alongside CPU use confined to about one quarter of one core.
- [ ] No labcap11 container remains running.
