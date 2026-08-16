# Chapter 11 — Model Observations

## Sharing two CPUs

Four equally nice CPU-bound workers accumulate similar, though not identical, tick counts. Their total is constrained by the two-CPU quota, so each gets roughly half a CPU while all four remain runnable.

## nice under CPU contention

With only one CPU available, the nice 0 worker accumulates substantially more ticks than the nice 15 worker. nice changes a runnable process's CPU scheduling weight; it does not reserve a CPU or make an otherwise idle process run faster.

## nice and I/O

The two dd reports can finish in either order. The nice values affect CPU scheduling, but they do not directly establish block-I/O priority. Cache behavior, the filesystem, the storage device, the container runtime, and the active I/O scheduler can dominate the measurement. A separate I/O-priority mechanism is needed where the kernel and scheduler support it.

## High load, low CPU use

Twelve CPU-bound processes remain runnable, but the cgroup quota allows their container only one quarter of one CPU. The runnable count is therefore high while docker stats stays near 25 percent of a single core. Load describes demand waiting for service, not the percentage of all physical CPU capacity currently in use.
