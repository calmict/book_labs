# Chapter 11 — Observations

## Sharing two CPUs

    Worker 1 ticks:
    Worker 2 ticks:
    Worker 3 ticks:
    Worker 4 ticks:

How evenly was CPU time divided?

## nice under CPU contention

    nice 0 ticks:
    nice 15 ticks:

Why does the difference appear only when the processes contend for CPU time?

## nice and I/O

    nice 0 dd throughput:
    nice 15 dd throughput:
    Host I/O scheduler:

Did the lower CPU nice value reliably make I/O finish first? Explain the roles of the I/O scheduler, filesystem, cache, and storage.

## High load, low CPU use

    /proc/loadavg:
    docker stats CPU percentage:

Explain why the runnable queue can be long even though the container is allowed to use only a fraction of one core.
